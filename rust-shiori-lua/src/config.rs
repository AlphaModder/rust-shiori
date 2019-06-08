use std::path::{Path, PathBuf};

use config::{Config as RawConfig, File, FileFormat};
use serde::Deserialize;

pub use config::ConfigError;

#[derive(Deserialize)]
pub struct Config {
    pub lua: Lua,
    pub logging: Logging,
}

#[derive(Deserialize)]
pub struct Lua {
    pub init: String,
    pub script_path: Vec<PathBuf>,
    pub library_path: Vec<PathBuf>,
    pub persistent: PathBuf,
}

#[derive(Deserialize)]
pub struct Logging {
    pub level: log::LevelFilter,
    pub path: PathBuf,
}

impl Config {
    pub fn try_load(path: &Path) -> Result<Self, ConfigError> {
        let mut config = RawConfig::new();
        config.merge(File::from_str(include_str!("default.toml"), FileFormat::Toml))?;
        config.merge(File::from(path).required(false))?;
        config.try_into()
    }
}