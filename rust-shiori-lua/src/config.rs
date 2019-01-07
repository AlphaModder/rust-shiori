use serde::Deserialize;
use config_rs::{Config as RawConfig, File, FileFormat, ConfigError};
use std::path::{Path, PathBuf};

#[derive(Deserialize)]
pub struct Config {
    pub search_paths: Vec<PathBuf>,
}

impl Config {
    pub fn try_load(path: &Path) -> Result<Self, ConfigError> {
        let mut config = RawConfig::new();
        config.merge(File::from_str(include_str!("default.toml"), FileFormat::Toml))?;
        config.merge(File::from(path).required(false))?;
        config.try_into()
    }
}