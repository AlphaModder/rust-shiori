use std::fmt;

#[derive(Debug)]
pub enum LoadError {
    ConfigError(config::ConfigError),
    IOError(std::io::Error),
    LogError(log::SetLoggerError),
    LuaError(rlua::Error),
}

impl From<config::ConfigError> for LoadError {
    fn from(error: config::ConfigError) -> Self {
        LoadError::ConfigError(error)
    }
}

impl From<std::io::Error> for LoadError {
    fn from(error: std::io::Error) -> Self {
        LoadError::IOError(error)
    }
}

impl From<log::SetLoggerError> for LoadError {
    fn from(error: log::SetLoggerError) -> Self {
        LoadError::LogError(error)
    }
}

impl From<rlua::Error> for LoadError {
    fn from(error: rlua::Error) -> Self {
        LoadError::LuaError(error)
    }
}

impl fmt::Display for LoadError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let (ty, message) = match &self {
            LoadError::ConfigError(e) => ("A configuration", format!("{}", e)),
            LoadError::IOError(e) => ("An IO", format!("{}", e)),
            LoadError::LogError(e) => ("A logging", format!("{}", e)),
            LoadError::LuaError(e) => ("A lua", format!("{}", e)),
        };
        write!(f, "{} error occured while loading the SHIORI. Details:\n{}", ty, message)
    }
}

pub enum UnloadError {
    IOError(std::io::Error),
    LuaError(rlua::Error),
}

impl From<std::io::Error> for UnloadError {
    fn from(error: std::io::Error) -> Self {
        UnloadError::IOError(error)
    }
}

impl From<rlua::Error> for UnloadError {
    fn from(error: rlua::Error) -> Self {
        UnloadError::LuaError(error)
    }
}

impl fmt::Display for UnloadError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let (ty, message) = match &self {
            UnloadError::IOError(e) => ("An IO", format!("{}", e)),
            UnloadError::LuaError(e) => ("A lua", format!("{}", e)),
        };
        write!(f, "{} error occured while unloading the SHIORI. Details:\n{}", ty, message)
    }
}