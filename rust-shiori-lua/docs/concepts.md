# Basic concepts

## Characters
All ghosts consist of one or more characters, each with their own set of sprites and textbox for speech. 

<a id="Character_IDs"></a>Characters are associated with a numeric ID in code, with the first character being `0` and subsequent characters `1`, `2`, `3`, etc. The characters with ID `0` and `1` and traditionally referred to as 'sakura' and 'kero' respectively.

## Events
The SHIORI protocol is designed around the concept of events, which represent some form of interaction from the environment (typically the user). All events have an <a id="Event_IDs"></a> event ID, which is a string that indicates the type of event. Depending on the ID, events may have various parameters that describe exactly what input the ghost recieved. A ghost recieves a stream of these events, and takes actions based on their parameters. To see how this works, refer to [Basic event management](./script_api.md#basic-event-management).  

There are two types of event, `GET` and `NOTIFY`. There are two key differences between the two. First, most operations that are directly visible to the user, like speaking or changing sprites, are only possible in response to a `GET` event, and will fail otherwise. Second, during a `GET` event, only the most recently registered applicable event handler (if any) will be called, while during a `NOTIFY` event, *all* applicable event handlers will be called. The order in which handlers are called during a `NOTIFY` event is undefined.
