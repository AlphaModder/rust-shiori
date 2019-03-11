use std::path::PathBuf;
use std::ffi::OsString;

#[cfg(windows)]
use self::os_str::OsStringExt; // Implements `OsString::into_vec` on Windows.
#[cfg(any(target_os = "redox", unix))]
use std::os::unix::ffi::OsStringExt;

use rust_shiori::{
    shiori, Shiori,
    request::{Request, Method},
    response::{Response, ResponseStatus, ResponseBuilder}
};

use rlua::{Lua, Table, Function, Context};

mod os_str;
mod config;
use self::config::Config;

shiori!(LuaShiori);

#[allow(unused)]
pub struct LuaShiori {
    path: PathBuf,
    config: config::Config,
    responder: rlua::RegistryKey,
    lua: Lua,
}


impl Shiori for LuaShiori {
    type LoadError = LoadError;
    fn load(path: PathBuf) -> Result<Self, LoadError> {
        let config = Config::try_load(&path.join("shiori.toml"))?;
        let lua = Lua::new();

        let preload_modules = [
            ("fstring", include_str!("rt/fstring.lua"), "format strings"),
            ("utils", include_str!("rt/utils.lua"), "shiori utils"),
            ("sakura", include_str!("rt/sakura.lua"), "sakura library"),
            ("shiori", include_str!("rt/shiori.lua"), "shiori ibrary"),
        ];

        lua.context(|ctx| -> rlua::Result<_> {
            let preload = ctx.globals().get::<_, Table>("package")?.get::<_, Table>("preload")?;
            for module in &preload_modules {
                preload.set::<_, Table>(module.0, ctx.load(module.1).set_name(module.2)?.call(())?)?;
            }
            Ok(())
        })?;

        let responder = lua.context(|ctx| -> rlua::Result<_> {
            let runtime: Table = ctx.load(include_str!("rt/utils.lua")).set_name("shiori utils")?.call(())?;
            let responder = ctx.create_registry_value(runtime.get::<_, Function>("respond")?)?;
            
            let separator = OsString::from(";");
            let path_string = ctx.create_string(
                &config.search_paths.iter()
                    .map(|p| path.join(p))
                    .flat_map(|p| vec![p.join("?.lua"), p.join("/?/init.lua")])
                    .enumerate()
                    .fold(OsString::new(), |mut os_str, (index, p)| {
                        if index != 0 { os_str.push(&separator) }
                        os_str.push(p.into_os_string());
                        os_str
                    }).into_vec()
            )?;

            runtime.get::<_, Function>("init")?.call::<_, ()>(path_string)?;
            Ok(responder)
        })?;

        Ok(LuaShiori {
            path: path,
            config: config,
            responder: responder,
            lua: lua,
        })
    }

    fn respond(&mut self, request: Request) -> Response {
        let mut response = ResponseBuilder::new().with_field("Charset", "UTF-8");

        let respond_raw = |ctx: Context| -> rlua::Result<(Option<String>, u32)> {
            let field_table = ctx.create_table_from(request.fields().into_iter().map(|(k, v)| (k.as_str(), v.as_str())));
            let response = ctx.registry_value::<Function>(&self.responder)?.call::<_, Table>(field_table)?;
            Ok((response.get("response")?, response.get("code")?))
        };

        match self.lua.context(respond_raw) {
            Ok((r, c)) => {
                let status = ResponseStatus::from_code(c).unwrap_or(ResponseStatus::InternalServerError);
                response = response.with_status(status);
                if request.method() == Method::Get && !status.is_error() {
                    response = response.with_field("Sender", "rust-shiori-lua");
                    if let Some(r) = r {
                        response = response.with_field("Value", &r);
                    }
                }
            },
            Err(_) => {
                response = response.with_status(ResponseStatus::InternalServerError);
            }
        }
        response.build().unwrap()
    }
}

pub enum LoadError {
    ConfigError(config::ConfigError),
    LuaError(rlua::Error),
}

impl From<config::ConfigError> for LoadError {
    fn from(error: config::ConfigError) -> Self {
        LoadError::ConfigError(error)
    }
}

impl From<rlua::Error> for LoadError {
    fn from(error: rlua::Error) -> Self {
        LoadError::LuaError(error)
    }
}