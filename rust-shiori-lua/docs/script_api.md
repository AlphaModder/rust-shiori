# Lua scripting interface (for ghost developers)

## The `shiori` table
Any references to `shiori` in this document should be assumed to refer to the global table of that name, through which most of rust-shiori-lua's functionality can be accessed.

## Character sets
The function `shiori.CharacterSet(cid0 [, cid1, cid2, ...])` 
creates a `CharacterSet` object containing all the characters whose [character IDs](./concepts.md#Character_IDs) were passed as arguments. Calling this object like a function with a line of dialogue will have all those characters say that dialogue simultaneously. For example:

```lua
local sakura = shiori.CharacterSet(0)
local kero = shiori.CharacterSet(1)
local both = shiori.CharacterSet(0, 1)

sakura "Hello world from Sakura!\n" 
kero "Hello world from Kero!\n"
both "Hello world from Sakura & Kero!\n"
```

Two `CharacterSet` objects can be combined with the `+` operator, resulting in a new `CharacterSet` containing all characters that were in either. This result can be saved to a local and given a name or used directly. However, in the latter case you *must* surround the expression in parentheses. The following example demonstrates this usage:

```lua
-- This works:
local both = sakura + kero
both "Hello world from Sakura & Kero!\n"

-- And so does this:
(sakura + kero) "Hello world from Sakura & Kero!\n"

-- But this doesn't:
sakura + kero "Hello world from Sakura & Kero!\n"
```

## Basic event management
By defining a function on the global table `event` (also accessible as `shiori.event`), a ghost may register an event handler which will be called when an event with the corresponding ID occurs. For instance, the following code makes the character with ID 0 say goodbye to the previous ghost after it has been initialized.
```lua
function event.OnGhostChanged(prev_sakura_name, prev_script, prev_name, prev_path, current_shell)
    local sakura = shiori.CharacterSet(0)
    sakura "Bye bye, ${prev_sakura_name}!"
end
```

## Logging
- `log(level, text, ...)`  
  Sends a log entry with level `level` to the rust-shiori-lua log file. The entry will contain the current line and file, as well as a message obtained by passing `text` and any further arguments to `string.format`. `log` is a global function.

  `level` must be one of `"trace"`, `"debug"`, `"info"`, `"warn"`, or `"error"`. Global functions with each of these names also exist, which log a message of the appropriate level and are called just like `log` but omit the `level` parameter. 

- `log_inner(level, text, params, [stack = 1])`  
  Sends a log entry with level `level` to the rust-shiori-lua log file. The entry will contain the line and file of the code currently executing `stack` stack levels above log_inner, as well as a message obtained by passing `text` and all elements of `params` to `string.format`. `log_inner` is a global function.

## Raising errors
The `shiori` module exposes a few methods for raising errors that will be understood by both lua and the SHIORI protocol. Note that these functions should be used instead of lua's global `error`, which has a different meaning in `rust-shiori-lua`. (See [Logging](#Logging).) Like `error`, they prevent execution if uncaught, and so should only be used to indicate unrecoverable errors.

- `shiori.bad_request(message, [level = 1])`  
  Raises a lua error with message `message` that if uncaught will become a SHIORI protocol `400 Bad Request`. The error will be associated with the function `level` stack levels above `bad_request`.

  This function can also be accessed directly through the global `bad_request`.
- `shiori.script_error(message, [level = 1])`  
  Raises a lua error with message `message` that if uncaught will become a SHIORI protocol `500 Internal Server Error`. The error will be associated with the function `level` stack levels above `script_error`.

  This function can also be accessed directly through the global `script_error`.

## Advanced event management
These functions allow the implementation of more complex event-handling patterns, such as one-time responses, filtered events, and resumable scripts. 

- `shiori.resume_on_events(event_table)`  
  Pauses the script at its current point of execution, and waits for an event that matches one of the entries in `event_table` to occur. Returns the id of the matching event and a list containing its arguments. Each entry in `event_table` should be one of the following:
  - A string array element, indicating an event ID to resume on unconditionally if encountered.
  - A string key whose value is a 'filter function'. If an event with an ID matching the key occurs, and the filter function returns `true` when passed the event's parameters, the script will be resumed.
  
  For example, if there is an event `AlwaysResume` and an event `MaybeResume` whose first parameter is a boolean indicating whether to resume:
  ```lua
  shiori.resume_on_events {
      "AlwaysResume",
      MaybeResume = function(resume) return resume end
  }
  ```

  Note that `resume_on_events` takes priority over previously-registered handlers, such that the script will be resumed *instead* of the normal handler being called, if any exists. 

- `shiori.resume_on_event(event, [filter])`  
  Pauses the script at its current point of execution, and waits for an event with ID `event` that passes the filter function `filter` to occur before resuming. If `filter` is omitted, resumes unconditionally. See `resume_on_events` above for definition of a filter function.

- `shiori.set_event_preprocessor(event, preprocessor)`  
  Updates the preprocessor for events with ID `event` to be the function specified by `preprocessor`.
  When `rust-shiori-lua` recieves an event, it first passes a table whose key-value pairs contain the event's raw SHIORI headers to the preprocessor with the corresponding ID. The preprocessor must then return a sequence of values, which are passed to matching event handlers as function arguments. 
 
  If you are using custom events, or wish to alter the format in which a default event is passed to handlers, you can use this function to install a new preprocessor.
  
  

