#![crate_type = "cdylib"]
extern crate config as config_rs;

use std::path::{Path, PathBuf};
use std::ffi::OsString;
use std::os::windows::ffi::OsStrExt;
use std::borrow::Borrow;

use rust_shiori::{shiori, Request, Response, response::ResponseStatus};

use rlua::{Lua, Table, Function, Value, FromLua};

mod config;
mod error;

use self::error::{LoadError, RespondError};
use self::config::Config;

shiori! { respond }

pub struct LuaShiori {
    path: PathBuf,
    config: config::Config,
    responder: rlua::RegistryKey,
    lua: Lua,
}

impl LuaShiori {
    pub fn load(path: PathBuf) -> Result<Self, LoadError> {
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

    pub fn respond(&mut self, request: Request) -> Response {
        let response = self.respond_raw(request);
        Response {
            status: match response {
                Ok(_) => ResponseStatus::OK,
                Err(RespondError::LuaError())
            }
        }
        unimplemented!()
    }

    pub fn unload(&mut self) {

    }
}

impl LuaShiori {
    fn create_lua(path: &Path, config: &Config) -> Result<Lua, rlua::Error> {
        let lua = Lua::new();

        fn write_utf16<'a, W: byteorder::WriteBytesExt>(container: &mut W, utf16: impl IntoIterator<Item=impl Borrow<u16>>) {
            for c in utf16 {
                container.write_u16::<byteorder::NativeEndian>(*c.borrow()).unwrap();
            }
        }
        
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

        Ok(lua)
    }

    fn respond_raw(&mut self, request: Request) -> Result<rlua::String, RespondError> {
        let response = self.lua.registry_value::<Function>(&self.responder)?.call::<_, Value>(request.fields().clone())?;
        if let Value::Error(e) = response {
            return Err(RespondError::ScriptError(e))
        }
        Ok(rlua::String::from_lua(response, &self.lua)?)
    }
}

pub fn respond(request: Request) -> Response {
    unimplemented!()
}

