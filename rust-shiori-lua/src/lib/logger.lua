local logger = {}

function logger.log_inner(level, text, params, stack)
    text = string.format(text, table.unpack(params))
    stack = stack or 1
    info = debug.getinfo(1 + stack, "Sl")
    _log(level, text, info.short_src, info.currentline)
end

function logger.log(level, text, ...) logger.log_inner(level, text, {...}, 2) end

for _, level in ipairs({"trace", "debug", "info", "warn", "error"}) do
    logger[level] = function(text, ...) logger.log_inner(level, text, {...}, 2) end
end

return logger