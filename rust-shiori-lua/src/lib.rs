#![crate_type = "cdylib"]
extern crate config as config_rs;

use std::path::PathBuf;
use std::ffi::OsString;
use std::os::windows::ffi::OsStrExt;
use std::borrow::Borrow;

use rust_shiori::{
    shiori, Shiori,
    request::{Request, Method},
    response::{Response, ResponseStatus, ResponseBuilder}
};

use rlua::{Lua, Table, Function};

mod config;
mod error;

use self::error::LoadError;
use self::config::Config;

shiori!(LuaShiori);

pub struct LuaShiori {
    path: PathBuf,
    config: config::Config,
    responder: rlua::RegistryKey,
    lua: Lua,
}

impl Shiori for LuaShiori {
    type LoadError = LoadError;
    fn load(path: PathBuf) -> Result<Self, LoadError> {
        fn write_utf16<'a, W: byteorder::WriteBytesExt>(container: &mut W, utf16: impl IntoIterator<Item=impl Borrow<u16>>) {
            for c in utf16 {
                container.write_u16::<byteorder::NativeEndian>(*c.borrow()).unwrap();
            }
        }

        let config = Config::try_load(&path.join("shiori.toml"))?;
        let lua = {
            let lua = Lua::new();
            let separator = OsString::from(";").encode_wide().collect::<Vec<u16>>();
            let path_string = lua.create_string(
                &config.search_paths.iter()
                    .map(|p| path.join(p))
                    .flat_map(|p| vec![p.join("?.lua"), p.join("/?/init.lua")])
                    .enumerate()
                    .fold(Vec::new(), |mut vec, (index, p)| {
                        if index != 0 { write_utf16(&mut vec, &separator); }
                        write_utf16(&mut vec, p.into_os_string().encode_wide());
                        vec
                    })
                )?;
            lua.globals().get::<_, Table>("package")?.set("path", path_string)?;
            lua
        };
        
        let responder = lua.create_registry_value(lua.exec::<_, Function>(include_str!("lua/runtime.lua"), Some("shiori runtime"))?)?;

        Ok(LuaShiori {
            path: path,
            config: config,
            responder: responder,
            lua: lua,
        })
    }

    fn respond(&mut self, request: Request) -> Response {
        let mut response = ResponseBuilder::new().with_field("Charset", "UTF-8");

        let respond_raw = || -> Result<(Option<String>, u32), rlua::Error> {
            let field_table = self.lua.create_table_from(request.fields().into_iter().map(|(k, v)| (k.as_str(), v.as_str())));
            let response = self.lua.registry_value::<Function>(&self.responder)?.call::<_, Table>(field_table)?;
            Ok((response.get("response")?, response.get("code")?))
        };

        match respond_raw() {
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