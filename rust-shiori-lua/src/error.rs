use rlua::Error as LuaError;
use config_rs::ConfigError;

pub enum LoadError {
    ConfigError(ConfigError),
    LuaError(LuaError),
}

impl From<ConfigError> for LoadError {
    fn from(error: ConfigError) -> Self {
        LoadError::ConfigError(error)
    }
}

impl From<LuaError> for LoadError {
    fn from(error: LuaError) -> Self {
        LoadError::LuaError(error)
    }
}