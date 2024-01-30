------------------------ GOBAL VARS ----------------------------
debug = false

--------------------------- TIMER ------------------------------

function timer_handler (emit)
end
  
  --------------------------- HOOKS ------------------------------
  
function init (emit)
    processed = 0
    errorCount = 0
    lastReloadDictonary = -1
end

function shutdown (emit)
end

function process (event, emit)
    if debug == true then
        print("0. process","event.log.message:", event.log.message)
        print("1. process","event.log.unparsed:", event.log.unparsed)
    end

    status, result = pcall(parse_message, event)
    if status == true then -- проверка на исключение
        emit(result)
    else
        print("ERROR parsing", result, event.log.unparsed)
        event.log.errLUA  = true
        event.log.err     = result
    end 
end

function parse_message(event)
    local msg = event.log.unparsed
    local msg_str = split_by_CR(msg)
    local count = #msg_str
    if debug == true then
        print("2. parse_message unparsed","count:", count, "msg_str[count]", msg_str[count])
    end

    local control = string.gsub(msg_str[count], '%s+', '')
    if control == "}," then
        -- особенность чтения ЖР,
        -- в последней записи }, не читается,
        -- поэтому выравниваем счетчик, как-будто
        -- это поле отсутствует
        count = count - 1
    end

    if debug == true then
        print("3. parse_message","new count:", count, "control", control)
    end

    local unparsed = msg_str[0]
    local pre_last_index = count - 1
    for i = 1, (pre_last_index - 1) do
        unparsed = unparsed.."\n"..msg_str[i]
    end

    if debug == true then
        print("4. process parse_message", "unparsed:", unparsed)
        print("5. process parse_message", "unparsed end")
    end

    if debug == true then
        print("6. process pre_last_line", "index:", pre_last_index, "msg_str:", msg_str[pre_last_index])
    end

    local unparsed_end = ""
    status, result = pcall(parse_pre_last_line, event, msg_str[pre_last_index])
    if status == true then
        unparsed_end = result
    else
        print(
            "ERROR parsing pre last line", result, "count:", 
            count, "unparsed:", event.log.unparsed,
            "msg_line:", msg_str[(count - 1)])
        event.log.errLUA  = true
        event.log.err     = result
        error({result})
    end
    
    if debug == true then
        print("7. process after pre_last_line", "unparsed data and data presentation:", unparsed_end)
        print("8. process after pre_last_line", "unparsed end")
    end
    
   unparsed = unparsed.."\n"..unparsed_end

    if debug == true then
        print("9. process after pre_last_line", "full unparsed:", unparsed)
        print("10. process after pre_last_line", "full unparsed end")
    end

    -- второй проход
    -- парсим поля содержащие сложные 
    -- для парсинга данные
    -- комментарий, data и data presentation
    msg_str = split_by_CR(unparsed)
    count = #msg_str
    local meta_index = 0
    status, result = pcall(parse_data_and_presentation, event, msg_str)
    if status == true then
        meta_index = result
    else
        print(
            "ERROR parsing data line", result, "count:", 
            count, "message:", event.log.message,
            "msg_line:", unparsed)
        event.log.errLUA  = true
        event.log.err     = result
        error({result})
    end

    if debug == true then
        print("11. process parse_comment_and_metadata", "index:", meta_index, "msg_str:", msg_str[meta_index])
    end
    status, result = pcall(parse_comment_and_metadata, event, msg_str, meta_index)
    if status ~= true then
        print(
            "ERROR parsing comment line 147", result, "meta_index:", 
            meta_index, "message:", event.log.unparsed,
            "msg_line:", msg_str[meta_index])
        event.log.errLUA  = true
        event.log.err     = result
        error({result})
    end
    
    return event
end

function split_by_comma(text)
    local text_lines = {}
    local index = 0
    for word in string.gmatch(text, '([^,]+)') do        
        if (word ~= nil) then
            local control = string.gsub(word, '%s+', '')
            if (control ~= "") then
                text_lines[index] = word
                index = index + 1
            end
        end
    end

    return text_lines
end

function split_by_colon(text)
    local text_lines = {}
    local index = 0
    for word in string.gmatch(text, '([^:]+)') do
        text_lines[index] = word
        index = index + 1
    end

    return text_lines
end

function split_by_CR(text)
    if debug == true then
        print("split_by_CR","text", text)
    end

    local msg_str = {}
    local index = 0 
    -- разбираем сообщение на строки
    for str in text:gmatch("([^\n]*)\n?") do
        if debug == true then
            print("split_by_CR","msg line")
            print("index:", index,"msg str", str)
        end
        msg_str[index] = str
        index = index + 1
    end

    return msg_str
end

function replace(word, pattern, str)
    local result = word:gsub(pattern, str)
    return result
end

function isempty(data)
    return data == nil or data == ''
end
--[[
function parse_first_line(event, msg_str)
    if debug == true then
        print("parse_first_line", "msg_str", msg_str)
    end
    -- в 0-строке всегда дата и статус транзакции
    local data = split_by_comma(msg_str)
    -- дату и время обрабатываем при при чтении
    -- сообщения из файла
    --event.log.Date = replace(data[0], "{", "")
    --event.log.DateLocal = event.log.Date
    event.log.TransactionStatus = data[1]
end

function parse_second_line(event, msg_str)
    if debug == true then
        print("parse_second_line", "msg_str", msg_str)
    end
    -- в 1-строке всегда:
    --      Транзакция, Пользователь, Компьютер
    --      Приложение, Соединение, Событие, Важность
    -- могут быть еще комментарий и индекс метаданных, 
    -- но, т.к. в комментарий может быть записана 
    -- произвольная информация, то определение 
    -- значения этих полей необходимо выполнять отдельно

    local data = split_by_comma(msg_str)
    local data_count = #data
    event.log.TransactionID = data[0]..","..data[1]
    event.log.User          = data[2]
    event.log.Computer      = data[3]
    event.log.Application   = data[4]
    event.log.Connection    = data[5]
    event.log.Event         = data[6]
    event.log.Level         = data[7]

    local unparsed = data[8]
    for i = 9, data_count do
        unparsed = unparsed..","..data[i]
    end

    if debug == true then
        print("parse_second_line", "unparsed", unparsed)
    end

    return unparsed
end
--]]
function parse_pre_last_line(event, msg_str)
    if debug == true then
        print("parse_pre_last_line", "msg_str", msg_str)
    end
    -- в предпоследней строке содержатся:
    --      Данные, Представление данных
    --      Сервер, Порт, Доп.порт, сеанс 
    --      и количество дополнительных данных
    --
    -- данные могут быть представлены различными типами:
    -- {"U"} - неопределены, для них представление данных = ""
    -- {"R",....} - ссылка на данные ИБ
    -- {"S","Строка"} - строка произвольной формы, 
    --      может содержать переносы строк и спец.символы,
    --      из-за чего в предпоследней строке может оказаться
    --      как все значение, так и его окончание, без идентификатора
    --      представление данных в этом случае = ""
    -- {"P", ...} - мне не встретился, но предполагаем аналог
    --      худшего варианта, т.е. "S"
    --
    -- из-за этого читаем строку с конца
    local data = split_by_comma(msg_str)    
    local data_count = #data
    if debug == true then
        print("parse_pre_last_line", "data_last_index", data_count)
    end
    event.log.Server    = data[(data_count - 4)]
    event.log.Port      = data[(data_count - 3)]
    event.log.SyncPort  = data[(data_count - 2)]
    event.log.Session   = data[(data_count - 1)]

    local unparsed = data[0]
    for i = 1, (data_count - 5) do
        unparsed = unparsed..","..data[i]
    end

    if debug == true then
        print("parse_pre_last_line", "unparsed", unparsed)
    end

    return unparsed
end

-- остается распарсить массив строк с комментарием, метаданными,
-- данными и представлением данных
-- данные строки находятся в конце второй строки, после Level
-- и заканчиваются в начале предпоследней строки, перед Server.
-- сложность разбора этих строк в практически произвольном содержании,
-- что в большей степени касается комментария и данных.
-- но и в наименовании справочника, которое попадет в поле представления данных,
-- тоже может быть помещен произвольный текст.

-- допущения необходимые для парсинга комментария
-- 1. комментарий начинается символом '"' 
--      и заканчивается символами '",\d{1-15},({"U"},"",|{"R",\d{0-15}:|{"S","|{"P",{'
-- 2. внутри комментария всегда парное количество "
-- 
-- для парсинга данных и представления данных:
-- 1. самый простой случай если unparsed предпоследней строки
--      в крайнем элементе содержит "", то это:
--          a) {"U"} - идентификатор в 0-элементе тойже строки
--          b) {"S"} - может быть многострочным, поэтому надо 
--              будет идти парсингом вверх по массиву строк
--          c) {"P"} - не встречал, но делаем аналогично {"S"}
-- 2. в крайнем элементе(представление данных) не "", 
--      значит в 0-элементе ожидаем {"R"}, все это находится 
--      в одной строке, т.к. первичное деление сообщения идет
--      по переносу строки
-- 3. в поле "представление данных" всегда парное количество
--      знаков '"'
-- 4. не зависимо от количества строк в значение поля данные
--      символы { и } всегда парные. Т.е. начав подсчет скобок
--      с конца строки получив в счетчике 0, считаем что
--      значение поля данные выбрано полностью

function parse_data_and_presentation(event, msg_str)
    local count = #msg_str
    local data_descr = msg_str[count]

    if debug == true then
        print("parse_data_and_presentation", "data descr", data_descr)
    end
    -- первый случай {"U"},""
    --print(string.find(data, '{"U"},""'))
    --print(string.match(data, '{"R",%d{0-15}:'))
    if string.find(data_descr, '{"U"},""') then
        parse_data_and_presentation_U(event, data_descr)
        -- вернем номер строки, в конце которой лежит
        -- идентификатор метаданных
        return (count - 1)
    elseif string.match(data_descr, '{"R",%d+:') then
        parse_data_and_presentation_R(event, data_descr)
        -- вернем номер строки, в конце которой лежит
        -- идентификатор метаданных
        return (count - 1)
    else
        local data_line = parse_data_and_presentation_SnP(event, msg_str)
        -- вернем номер строки, в конце которой лежит
        -- идентификатор метаданных
        return (data_line - 1)
    end
end

function parse_data_and_presentation_R(event, data_descr)
    local data_str = string.match(data_descr, '{"R",%d+:%w+}')
    --print("------{R}", data_str)
    local data_array = split_by_comma(data_str)
    local obj_data = split_by_colon(data_array[1])
    --print("------{R} obj ", obj_data[0], obj_data[1])
    event.log.Data      = data_str
    event.log.DataType  = obj_data[0]
    local status, result = pcall(replace,obj_data[1], "}", "")
    if status == true then        
        event.log.DataRef = result
    else
        print("ERROR replace 248", obj_data[1])
        error({result})
    end

    status, result = pcall(replace,data_descr, data_str..",", "")
    if status == true then        
        event.log.DataPresentation = result:gsub('"','')
    else
        print("ERROR replace 255", data_descr, data_str..",")
        error({result})
    end
end

function parse_data_and_presentation_U(event, data_descr)
    event.log.Data      = '{"U"}'
    event.log.DataType  = ""
    event.log.DataRef   = ""
    event.log.DataPresentation = ""
end

function parse_data_and_presentation_SnP(event, msg_str)
    -- начинаем набирать строки снизу вверх считая {/}
    -- т.к. представление данных выражено как ""
    local right_bracket = 0
    local left_bracket  = 0
    local event_data    = ""
    local count = #msg_str

    for i = count, 0, -1 do
        local str = msg_str[i]
        local right_set, right_count = string.gsub(str, "}", "}")
        local left_set, left_count = string.gsub(str, "{", "{")
        right_bracket   = right_bracket + right_count
        left_bracket    = left_bracket + left_count
        -- набираем строку описания данных
        if i == count then
            -- отрежим представление данных
            local status, result = pcall(replace, str, '},""$', "}")
            if status == true then
                str = result
                event_data = str
            else
                print("ERROR replace 288", str)
                error({result})
            end            
        else
            event_data = str.."\n\r"..event_data
        end

        if right_bracket == left_bracket then
            event.log.Data      = event_data
            event.log.DataType  = ""
            event.log.DataRef   = ""
            event.log.DataPresentation = ""
            -- вернем номер строки, на которой завершилось
            -- описание данных
            return i
        end
    end
end

function parse_comment_and_metadata(event, msg_str, metadata_index)
    local event_comment = ""
    local data_descr    = msg_str[metadata_index]

    -- отсекае ID метаданных, первый проход
    local data_str      = string.match(data_descr, ',%d+,%s$')
    if debug == true then
        print("a) parse_comment_and_metadata", "data_str", data_str)
    end

    -- отсекае ID метаданных, второй проход
    if isempty(data_str) then
        -- окончание строки зависит от структуры
        -- комментария, в многострочном строка заканчивается "число,"
        -- в однострочном просто "число"
        data_str = string.match(data_descr, ',%d+%s$')
    end

    if debug == true then
        print("b) parse_comment_and_metadata", "data_str", data_str)
    end

    local status, result = pcall(replace, data_str, ",", "")
    if status ~= true then        
        print("ERROR replace 438", data_str, data_descr, result)
        error({result})
    end

    local status, result = pcall(replace, result, "%s", "")
    if debug == true then
        print("parse_comment_and_metadata", "result", result, ".")
    end
    event.log.Metadata = result

    -- удалим данные ID метаданных
    local status, result = pcall(replace, msg_str[metadata_index], data_str, "")
    if status == true then        
        msg_str[metadata_index] = result
    else
        print("ERROR replace 453")
        error({result})
    end

    -- собираем данные комментария
    for i = metadata_index, 0, -1 do
        local str = msg_str[i]
        -- набираем строку комментария
        if i == metadata_index then
            -- отрежим ид метаданных
            status, result = pcall(replace, str, ",%d+,$", "")
            if status == true then
                str = result
            else
                print("ERROR replace 467", str, result)
                error({result})
            end
            event_comment = str
        else
            event_comment = str.."\n\r"..event_comment
        end
    end

    event.log.Comment = event_comment
end