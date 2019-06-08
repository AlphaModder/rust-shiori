use std::ffi::OsString;
use std::fs::File;
use std::path::{Path, PathBuf};
use std::ops::Deref;

#[cfg(windows)]
use self::os_str::OsStringExt; // Implements `OsString::into_vec` on Windows.
#[cfg(any(target_os = "redox", unix))]
use std::os::unix::ffi::OsStringExt;

use include_lua::*;

use log::{info, debug, warn, error, Level, Record};

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
mod persistent;

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

impl LuaShiori {
    fn load(path: PathBuf) -> Result<Self, LoadError> {
        let config = Config::try_load(&path.join("rust-shiori.toml"))?;

        if config.logging.level != log::LevelFilter::Off {
            let log_file = File::create(&path.join(&config.logging.path))?;
            let log_config = LogConfig { target: Some(log::Level::Trace), .. LogConfig::default() };
            WriteLogger::init(config.logging.level, log_config, log_file)?;
            debug!("Logging successfully initialized.");
        }

        let lua = unsafe { Lua::new_with_debug() }; // Debug for fstrings. Not present in script environment.
        let responder = lua.context(|ctx| -> Result<_, LoadError> {
            Self::create_lua_logger(&ctx)?;
            debug!("Lua logging interface loaded.");

            // Self::add_notail_hack(&ctx)?;
            // debug!("Installed tail-call prevention hack.");

            let searcher = ctx.make_searcher(include_lua!("[shiori libs]": "lib"))?;
            debug!("Lua libraries loaded.");

            let runtime: Table = ctx.load(include_str!("runtime.lua")).set_name("shiori runtime")?.call(())?;
            debug!("Lua runtime loaded.");

            let responder = ctx.create_registry_value(runtime.get::<_, Function>("respond")?)?;
            debug!("Responder function created.");

            Self::set_lua_paths(&ctx, &path, &config)?;
            debug!("Lua search paths set.");

            ctx.globals().set("persistent", Self::load_persistent(&ctx, &config)?)?;
            debug!("Persistent data loaded.");
            
            runtime.get::<_, Function>("init")?.call((&*config.lua.init, searcher))?;
            debug!("Lua initialization complete.");

            Ok(responder)
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

    fn load_persistent<'a>(ctx: &Context<'a>, config: &Config) -> Result<Table<'a>, LoadError> {
        if let Ok(mut file) = File::open(&config.lua.persistent) {
            if let Ok(rmpv::Value::Map(m)) = rmpv::decode::read_value(&mut file) {
                return Ok(persistent::from_rmpv(ctx, m, "<root>".to_string())?)
            }
        }
        warn!("Persistent data located in {} was corrupt or missing.", config.lua.persistent.display());
        Ok(ctx.create_table()?)
    }

    fn unload_persistent(&mut self) -> Result<(), UnloadError> {
        self.lua.context(|ctx| {
            let persistent = persistent::to_rmpv(ctx.globals().get("persistent")?, "<root>".to_string());
            let mut file = File::create(&self.config.lua.persistent)?;
            rmpv::encode::write_value(&mut file, &persistent).map_err(|e| e.into_io())?;
            Ok(())
        })
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

    fn unload(&mut self) {
        if let Err(e) = self.unload_persistent() { error!("{}", e); }
    }
}

