use std::ffi::OsString;
use std::fs::File;
use std::path::{Path, PathBuf};
use std::ops::Deref;

#[cfg(windows)]
use self::os_str::OsStringExt; // Implements `OsString::into_vec` on Windows.
#[cfg(any(target_os = "redox", unix))]
use std::os::unix::ffi::OsStringExt;

use include_lua::*;

use log::{info, debug, error, Level, Record};

use rust_shiori::{
    shiori, Shiori,
    request::{Request, Method},
    response::{Response, ResponseStatus, ResponseBuilder}
};

use rlua::{Lua, Table, Function, Context};

use simplelog::{WriteLogger, Config as LogConfig};

mod os_str;
mod config;
mod error;
mod eris;

use self::config::Config;
use self::error::*;

const LUA_VERSION: &str = "5.3";

shiori!(LuaShiori);

#[allow(unused)]
pub struct LuaShiori {
    path: PathBuf,
    config: config::Config,
    lua: Lua,
    responder: rlua::RegistryKey,
}

struct ShioriInit<'a> {
    init: &'a str,
    searcher: Searcher,
    persistent_path: &'a str,
}

impl<'lua, 'a> rlua::ToLuaMulti<'lua> for ShioriInit<'a> {
    fn to_lua_multi(self, lua: Context<'lua>) -> rlua::Result<rlua::MultiValue> {
        rlua::ToLuaMulti::to_lua_multi((self.init, self.searcher, self.persistent_path), lua)
    }
}

impl LuaShiori {
    fn load(path: PathBuf) -> Result<Self, LoadError> {
        let config = Config::try_load(&path.join("rust-shiori.toml"))?;

        if config.logging.level != log::LevelFilter::Off {
            let log_file = File::create(&path.join(&config.logging.path))?;
            let log_config = LogConfig { target: Some(log::Level::Trace), .. LogConfig::default() };
            WriteLogger::init(config.logging.level, log_config, log_file)?;
            debug!("Logging successfully initialized.");
        }

        let mut lua = unsafe { Lua::new_with_debug() }; // Debug is used for error reporting.
        eris::load_eris(&mut lua);
        let responder = lua.context(|ctx| -> Result<_, LoadError> {
            Self::create_lua_logger(&ctx)?;
            debug!("Lua logging interface loaded.");

            let searcher = ctx.make_searcher(include_lua!("[shiori libs]": "lib"))?;
            debug!("Lua libraries loaded.");

            let responder_ctor: Function = ctx.load(include_str!("runtime.lua")).set_name("shiori runtime")?.call(())?;
            debug!("Lua runtime loaded.");

            Self::set_lua_paths(&ctx, &path, &config)?;
            debug!("Lua search paths set.");

            let init_params = ShioriInit { 
                init: &config.lua.init, 
                searcher: searcher, 
                persistent_path: &config.lua.persistent,
            };

            let responder = responder_ctor.call::<_, Function>(init_params)?;
            let responder_key = ctx.create_registry_value(responder)?;
            debug!("Responder created.");

            Ok(responder_key)
        })?;

        info!("SHIORI load complete.");

        Ok(LuaShiori {
            path: path,
            config: config,
            lua: lua,
            responder: responder,
        })
    }

    fn set_lua_paths(ctx: &Context, ghost_path: &Path, config: &Config) -> rlua::Result<()> {
        let separator = OsString::from(";");
        let package = ctx.globals().get::<_, Table>("package")?;
        let set_path = |path: &str, paths: &[PathBuf], suffixes: &[&str]| -> rlua::Result<()> {
            let path_str = ctx.create_string(
                &paths.iter()
                    .map(|p| ghost_path.join(p))
                    .flat_map(|p| suffixes.iter().map(move |s| p.join(s)))
                    .enumerate()
                    .fold(OsString::new(), |mut os_str, (index, p)| {
                        if index != 0 { os_str.push(&separator) }
                        os_str.push(p.into_os_string());
                        os_str
                    }
            ).into_vec())?;
            package.set(path, path_str)?;
            Ok(())
        };
    
        set_path("script_path", &config.lua.script_path, &["?.lua", "?/init.lua"])?;
        set_path("path", &config.lua.library_path, &["?.lua", "?/init.lua"])?;
        set_path("cpath", &config.lua.library_path, &["?.dll", &format!("clib/lua{}/?.dll", LUA_VERSION), "loadall.dll"])?;
        
        Ok(())
    }

    fn create_lua_logger(ctx: &Context) -> rlua::Result<()> {
        ctx.globals().set("_log", ctx.create_function(
            |_, (level, text, file, line): (String, String, Option<String>, Option<u32>)| {
                let level = level.parse().unwrap_or(Level::Debug);
                let mut record = Record::builder();
                record.level(level).file(file.as_ref().map(Deref::deref)).line(line);
                log::logger().log(&record.args(format_args!("{}", text)).build());
                Ok(())
            }
        )?)
    }
}

impl Shiori for LuaShiori {
    type LoadError = LoadError;
    fn load(path: PathBuf) -> Result<Self, LoadError> {
        match LuaShiori::load(path) {
            Ok(s) => Ok(s),
            Err(e) => { error!("{}", e); Err(e) },
        }
    }

    fn respond(&mut self, request: Request) -> Response {
        let mut response = ResponseBuilder::new().with_field("Charset", "UTF-8");

        let respond_raw = |ctx: Context| -> rlua::Result<(Option<String>, u32)> {
            let field_table = ctx.create_table_from(request.fields().into_iter().map(|(k, v)| (k.as_str(), v.as_str())))?;
            let response = ctx.registry_value::<Function>(&self.responder)?.call::<_, Table>((field_table, request.method().as_str()))?;
            Ok((response.get("text")?, response.get("code")?))
        };

        match self.lua.context(respond_raw) {
            Ok((r, c)) => {
                let status = ResponseStatus::from_code(c).unwrap_or(ResponseStatus::InternalServerError);
                response = response.with_status(status);
                if !status.is_error() {
                    if request.method() == Method::Get {
                        response = response.with_field("Sender", "rust-shiori-lua");
                        if let Some(r) = r {
                            response = response.with_field("Value", &r);
                        }
                    }
                }
                else {
                    match r {
                        Some(e) => error!("A script error occured while responding to a request. Details: {}", e),
                        None => error!("A script error occured while responding to a request. No details available."),
                    }
                }
            },
            Err(e) => {
                error!("An internal error occured while responding to a request. This is a bug! Details:\n{}", e);
                response = response.with_status(ResponseStatus::InternalServerError);
            }
        }
        
        response.build().unwrap()
    }
}

