pub enum SakuraScriptCommand {
    SetFont { name: String, filename: String },
    SetFontDefault,
    SetFontSize(u32),
    SetFontSizeRelative(i32),
    SetFontSizePercent(f32),
    SetFontSizePercentRelative(f32),
    SetFontSizeDefault,
}

macro_rules! sakura_command {
    { $name:expr } => { format!(r"\{}", $name) };
    { $name:expr, $($arg:expr),+ } => { format!(r"\{}[{}]", $name, &[$($arg),+].join(", ")) }
}

impl SakuraScriptCommand {
    fn as_command(&self) -> String {
        use SakuraScriptCommand::*;
        match self {
            SetFont { name, filename } => sakura_command!("f", "font", name, filename),
            SetFontDefault => sakura_command!("f", "font", "default"),
            SetFontSize(size) => { sakura_command!("f", "height", &size.to_string()) },
            SetFontSizeRelative(size) => { 
                sakura_command!("f", "height", &format!("{}{}", if *size < 0 { "" } else { "+" }, size))
            },
            SetFontSizePercent(size) => sakura_command!("f", "height", &format!("{}%", size * 100.0)),
            SetFontSizePercentRelative(size) => {
                sakura_command!("f", "height", &format!("{}{}%", if *size < 0.0 { "" } else { "+" }, size * 100.0))
            },
            SetFontSizeDefault => sakura_command!("f", "height", "default"),
        }
    }
}

pub enum CharacterCommands {
    
}