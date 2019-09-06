use std::os::raw::c_void;
use std::marker::PhantomData;
use std::cell::UnsafeCell;

use rlua::Lua;

extern "C" {
    pub fn rsl_loaderis(lua: *mut c_void);
}

struct LuaInternals {
    main_state: *mut c_void,
    _no_ref_unwind_safe: PhantomData<UnsafeCell<()>>
}

pub fn load_eris<'a>(lua: &'a mut Lua) {
    // this may technically be UB (Lua isn't #[repr(C)]) but it's temporary and works
    unsafe {
        let lua: &'a mut LuaInternals = std::mem::transmute(lua);
        rsl_loaderis(lua.main_state);
    }
}