use crate::request::{Method, Request as UntypedReq, FromRequestField};

pub struct TypedRequest<'a> {
    method: Method,
    version: &'a str,
    sender: Option<&'a str>,
    charset: Option<&'a str>,
    security_level: Option<&'a str>,
    id: Option<&'a str>,
    kind: RequestKind<'a>,
}

impl<'a> TypedRequest<'a> {
    pub fn from_untyped(untyped: &'a UntypedReq) -> Self {
        TypedRequest {
            method: untyped.method,
            version: &untyped.version,
            sender: untyped.get_field("Sender"),
            charset: untyped.get_field("Charset"),
            security_level: untyped.get_field("SecurityLevel"),
            id: untyped.get_field("ID"),
            kind: RequestKind::from_untyped(untyped),
        }
    }
}

pub enum RequestKind<'u> {
    OnFirstBoot(OnFirstBoot),
    OnBoot(OnBoot<'u>),
    OnClose(OnClose),
    OnCloseAll(OnCloseAll),
    OnGhostChanged(OnGhostChanged<'u>),
    OnGhostChanging(OnGhostChanging<'u>),
    OnGhostCalled(OnGhostCalled<'u>),
    OnGhostCalling(OnGhostCalling<'u>),
    OnGhostCallComplete(OnGhostCallComplete<'u>),
    OnOtherGhostBooted(OnOtherGhostBooted<'u>),
    OnOtherGhostChanged(OnOtherGhostChanged<'u>),
    OnOtherGhostClosed(OnOtherGhostClosed<'u>),
    OnShellChanged(OnShellChanged<'u>),
    OnShellChanging(OnShellChanging<'u>),
    OnDressupChanged(OnDressupChanged<'u>),
    Other,
}

impl<'u> RequestKind<'u> {
    fn from_untyped(untyped: &'u UntypedReq) -> Self {
        use self::RequestKind::*;
        match untyped.get_field("ID").unwrap_or("") {
            _ => Other
        }
    }
}

pub trait RequestType<'u>: Sized {
    const ID: &'static str;
    fn from_untyped(untyped: &'u UntypedReq) -> Result<Self, ()>;
}

#[derive(RequestType)]
pub struct OnFirstBoot { #[shiori(field = "Reference0")] pub times_uninstalled: usize }

#[derive(RequestType)]
pub struct OnBoot<'u> { 
    #[shiori(field = "Reference0")] pub shell: &'u str, 
    // TODO: #[shiori(field = "Reference6")] pub ???: Option<&'u str>,
    // TODO: #[shiori(field = "Reference7")] pub ???: Option<&'u str>,
}

pub enum CloseReason { User, System }

impl<'a> FromRequestField<'a> for CloseReason {
    fn from_request_field(field: Option<&'a str>) -> Result<Self, ()> {
        match field {
            Some("user") => Ok(CloseReason::User),
            Some("system") => Ok(CloseReason::System),
            _ => Err(())
        }
    }
}

#[derive(RequestType)]
pub struct OnClose { #[shiori(field = "Reference0")] pub reason: CloseReason }

#[derive(RequestType)]
pub struct OnCloseAll { #[shiori(field = "Reference0")] pub reason: CloseReason }

#[derive(RequestType)]
pub struct OnGhostChanged<'u> {
    #[shiori(field = "Reference0")] pub last_ghost_sakura: &'u str,
    #[shiori(field = "Reference1")] pub last_script: &'u str,
    #[shiori(field = "Reference2")] pub last_ghost: Option<&'u str>,
    #[shiori(field = "Reference3")] pub last_ghost_path: Option<&'u str>,
    #[shiori(field = "Reference7")] pub shell: Option<&'u str>,
}

pub enum SwitchType { Manual, Automatic }

impl<'a> FromRequestField<'a> for SwitchType {
    fn from_request_field(field: Option<&'a str>) -> Result<Self, ()> {
        match field {
            Some("manual") => Ok(SwitchType::Manual),
            Some("automatic") => Ok(SwitchType::Automatic),
            _ => Err(())
        }
    }
}

#[derive(RequestType)]
pub struct OnGhostChanging<'u> {
    #[shiori(field = "Reference0")] pub new_ghost_sakura: &'u str,
    #[shiori(field = "Reference1")] pub switch_type: SwitchType,
    #[shiori(field = "Reference2")] pub new_ghost_name: Option<&'u str>,
    #[shiori(field = "Reference3")] pub new_ghost_path: Option<&'u str>,
}

#[derive(RequestType)]
pub struct OnGhostCalled<'u> {
    #[shiori(field = "Reference0")] pub calling_ghost_sakura: &'u str,
    #[shiori(field = "Reference1")] pub calling_script: &'u str,
    #[shiori(field = "Reference2")] pub calling_ghost: &'u str,
    #[shiori(field = "Reference3")] pub calling_ghost_path: &'u str,
    #[shiori(field = "Reference7")] pub shell: &'u str,
}

#[derive(RequestType)]
pub struct OnGhostCalling<'u> {
    #[shiori(field = "Reference0")] pub called_ghost_sakura: &'u str,
    #[shiori(field = "Reference1")] pub switch_type: SwitchType,
    #[shiori(field = "Reference2")] pub called_ghost_name: &'u str,
    #[shiori(field = "Reference3")] pub called_ghost_path: &'u str,
}

#[derive(RequestType)]
pub struct OnGhostCallComplete<'u> {
    #[shiori(field = "Reference0")] pub calling_ghost_sakura: &'u str, 
    #[shiori(field = "Reference1")] pub calling_script: &'u str,
    #[shiori(field = "Reference2")] pub calling_ghost: &'u str,
    #[shiori(field = "Reference7")] pub calling_shell: &'u str, // ???
}

#[derive(RequestType)]
pub struct OnOtherGhostBooted<'u> {
    #[shiori(field = "Reference0")] pub booted_ghost_sakura: &'u str, 
    #[shiori(field = "Reference1")] pub booted_script: &'u str,
    #[shiori(field = "Reference2")] pub booted_ghost: &'u str,
    #[shiori(field = "Reference7")] pub booted_shell: &'u str,
}

#[derive(RequestType)]
pub struct OnOtherGhostChanged<'u> {
    #[shiori(field = "Reference0")] pub last_ghost_sakura: &'u str,
    #[shiori(field = "Reference1")] pub new_ghost_sakura: &'u str,
    #[shiori(field = "Reference2")] pub last_ghost_script: &'u str,
    #[shiori(field = "Reference3")] pub new_ghost_script: &'u str,
    #[shiori(field = "Reference4")] pub last_ghost: &'u str,
    #[shiori(field = "Reference5")] pub new_ghost: &'u str,
    #[shiori(field = "Reference14")] pub last_shell: &'u str,
    #[shiori(field = "Reference15")] pub new_shell: &'u str,
}

#[derive(RequestType)]
pub struct OnOtherGhostClosed<'u> {
    #[shiori(field = "Reference0")] pub closed_ghost_sakura: &'u str,
    #[shiori(field = "Reference1")] pub closed_script: &'u str,
    #[shiori(field = "Reference2")] pub closed_ghost: &'u str,
    #[shiori(field = "Reference7")] pub closed_shell: &'u str,
}

#[derive(RequestType)]
pub struct OnShellChanged<'u> {
    #[shiori(field = "Reference0")] pub current_shell: &'u str,
    #[shiori(field = "Reference1")] pub ghost: Option<&'u str>, // This is current_shell instead in CROW.
    #[shiori(field = "Reference2")] pub current_shell_path: Option<&'u str>,
}

#[derive(RequestType)]
pub struct OnShellChanging<'u> {
    #[shiori(field = "Reference0")] pub new_shell: &'u str,
    #[shiori(field = "Reference1")] pub last_shell: Option<&'u str>, 
    #[shiori(field = "Reference2")] pub new_shell_path: Option<&'u str>,
}

#[derive(RequestType)]
pub struct OnDressupChanged<'u> {
    #[shiori(field = "Reference0")] pub character: &'u str,
    #[shiori(field = "Reference1")] pub part: &'u str, 
    #[shiori(field = "Reference2")] pub valid: usize, // 1 if valid, 0 if not.
    #[shiori(field = "Reference3")] pub category: Option<&'u str>,
}

#[derive(RequestType)]
pub struct OnBalloonChange<'u> {
    #[shiori(field = "Reference0")] pub new_balloon: &'u str,
    #[shiori(field = "Reference1")] pub new_balloon_path: &'u str, 
}

#[derive(RequestType)]
pub struct OnWindowStateRestore;

#[derive(RequestType)]
pub struct OnWindowStateMinimize;

#[derive(RequestType)]
pub struct OnFullScreenAppMinimize;

#[derive(RequestType)]
pub struct OnFullScreenAppRestore;

//TODO: OnVirtualDesktopChanged

