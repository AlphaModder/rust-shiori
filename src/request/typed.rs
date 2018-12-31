use crate::request::{Method, Request as UntypedReq};

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
    Other(&'u UntypedReq),
}

impl<'u> RequestKind<'u> {
    fn from_untyped(untyped: &'u UntypedReq) -> Self {
        use self::RequestKind::*;
        match untyped.get_field("ID").unwrap_or("") {
            _ => Other(untyped)
        }
    }
}

pub struct OnFirstBoot { pub times_uninstalled: usize }
pub struct OnBoot<'u> { pub shell: &'u str }

pub enum CloseReason { User, System }
pub struct OnClose { pub reason: CloseReason }
pub struct OnCloseAll { pub reason: CloseReason }

pub struct OnGhostChanged<'u> {
    pub last_ghost_sakura: &'u str,
    pub last_script: &'u str,
    pub last_ghost: Option<&'u str>,
    pub last_ghost_path: Option<&'u str>,
    pub last_ghost_shell: Option<&'u str>,
}

pub enum SwitchType { Manual, Automatic }
pub struct OnGhostChanging<'u> {
    pub new_ghost_sakura: &'u str,
    pub switch_type: SwitchType,
    pub new_ghost_name: Option<&'u str>,
    pub new_ghost_path: Option<&'u str>,
}

pub struct OnGhostCalled {

}

pub trait RequestType: Sized {
    const ID: &'static str;
    fn from_untyped(untyped: &UntypedReq) -> Option<Self>;
}