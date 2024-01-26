dictonaryIndex = {"users","computers","applications","events","metadata","servers","ports","portsAdd"}
dictonaries = {users={}, computers={}, applications={}, events={}, metadata={}, servers={}, ports={}, portsAdd={}}

startEpoch = -62135632799
dictonaryFilePath = nil
fileProcessing = nil
env_onec_logs_debug = false
debug = false

function tableLength(table)
  count = 0
  for _ in pairs(table) do count = count + 1 end
  return count
end

function split(inputstr, sep)
  if sep == nil then sep = "%s" end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
    end
  return t
end

function getPath(str)
    return str:match("(.*[/\\/])")
end

function loadDictonary()
  print("LOG FILE:"..fileProcessing)
  print("LOG FILE PATH:"..getPath(fileProcessing))
  if dictonaryFilePath == nil then
    dictonaryFilePath = getPath(fileProcessing).."1Cv8.lgf"
  end  
  print("DICTONARY RELOAD: "..dictonaryFilePath)

  local file = io.open(dictonaryFilePath, "r")
    if not file then 
      print("DICTONARY not found: "..dictonaryFilePath)
      return nil 
    end
    local file_content = file:read "*a"
    file:close()

  for dictonary_type, value in file_content:gmatch('{(%d+),(.-)}') do
    local s, e, id = value:find("(%d+)$")
    local data   = value:sub(1, s-2)
    local dtype = tonumber(dictonary_type)

    if (dtype > 0) and (dtype < 9) then
      dictonaries[dictonaryIndex[dtype]][id] = data
    else 
      goto continue 
    end

  ::continue::  
  end
end

-- return {value, 
--  status = true - найден, false - не найден, 
--        nil - для поиска передано нулевое значение}
-- 
function getDictonaryValue(id, type)
  if id ~= "0" then
    local status, value  = pcall(function() return dictonaries[type][id] end, type, id)
    if status == false then
      print("DICTONARY FIND ERROR: type["..type.."]["..id.."]",value)
      value = nil
    end  
    
    if value ~= nil then 
      return {value=value, status=true}  
    else
      if lastReloadDictonary < processed then -- Обновим словарь если на этой строке лога мы его еще не обновляли
        loadDictonary()
        lastReloadDictonary = processed
        value = dictonaries[type][id] -- Повторим поиск
          if value ~= nil then 
            return {value=value, status=true}  
          else
            return {value=id, status=false}
          end
      else -- словарь уже обновлен поэтому вернес статус что значение не найдено
        return {value=id, status=false} 
      end
    end
  else
    return {value=id, status=nil}  
  end
end


--------------------------- TIMER ------------------------------

function timer_handler (emit)
  if env_onec_logs_debug == "true" then
    print("============================================================")
    print(os.date('%Y-%m-%d %H:%M:%S'), "PROCESSES", processed, "ERRORS", errorCount)
    print("============================================================")
  end
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
      local status = nil
      local result = {}
      processed = processed + 1
      fileProcessing = event.log.file
      
      event.log.UserUUID = ""
      event.log.MetadataUuid = ""
      event.log.errLUA = nil
      if debug == true then
        print("transform process","event.log.message", event.log.message)
      end
      
      --------------------------- USER ------------------------------
        status, result = pcall(getDictonaryValue, event.log.User, "users")
        if status == true then -- проверка на исключение
          if result.status == true then
            local userObj = split(result.value, ",")
            event.log.UserUUID = userObj[1]
            event.log.UserName = userObj[2]:gsub('"','')
          end
        else
          print("ERROR User", result)
          event.log.errLUA  = true
          event.log.err     = result
          errorCount = errorCount + 1
        end  
 
     --------------------------- COMPUTER ------------------------------
        status, result = pcall(getDictonaryValue, event.log.Computer, "computers")
        if status == true then -- проверка на исключение
          if result.status == true then
            event.log.ComputerName = result.value:gsub('"','')
          end
        else
          print("ERROR Computer", result, "input", event.log.User)
          event.log.errLUA  = true
          event.log.err     = result
          errorCount = errorCount + 1
        end  
     --------------------------- APPLICATION ------------------------------

        status, result = pcall(getDictonaryValue, event.log.Application, "applications")
        if status == true then -- проверка на исключение
          if result.status == true then
            event.log.ApplicationName = result.value:gsub('"','')
          end
        else
          print("ERROR Application", result, "input", event.log.Application)
          event.log.errLUA  = true
          event.log.err     = result
          errorCount = errorCount + 1
        end
     ------------------------------ EVENT ----------------------------------

        status, result = pcall(getDictonaryValue, event.log.Event, "events")
        if status == true then -- проверка на исключение
          if result.status == true then
            event.log.EventName = result.value
          end
        else
          print("ERROR Event", result, "input", event.log.Event)
          event.log.errLUA  = true
          event.log.err     = result
          errorCount = errorCount + 1
        end  

     ------------------------------ METADATA --------------------------------

        status, result = pcall(getDictonaryValue, event.log.Metadata, "metadata")
        if status == true then -- проверка на исключение
          if result.status == true then
            local metaObj = split(result.value,",")
            event.log.MetadataUuid = metaObj[1]
            event.log.MetadataName = metaObj[2]          
          end
        else
          print("ERROR Metadata", result, "input", event.log.Metadata)
          event.log.errLUA  = true
          event.log.err     = result
          errorCount = errorCount + 1
        end

     -------------------------------- DATA ----------------------------------
        data_type = event.log.DataType
        if (data_type ~= nil) and (data_type ~= "") then
          status, result = pcall(getDictonaryValue, event.log.DataType, "metadata")
          if status == true then -- проверка на исключение
            if result.status == true then
              local metaObj = split(result.value,",")
              --event.log.MetadataUuid = metaObj[1]
              event.log.DataTypeName = metaObj[2]          
            end
          else
            print("ERROR Metadata", result, "input", event.log.Metadata)
            event.log.errLUA  = true
            event.log.err     = result
            errorCount = errorCount + 1
          end
        end
     -------------------------------- SERVER --------------------------------

        status, result = pcall(getDictonaryValue, event.log.Server, "servers")
        if status == true then -- проверка на исключение
          if result.status == true then
            event.log.ServerName = result.value:gsub('"','')
          end
        else
          print("ERROR Server", result, "input", event.log.Server)
          event.log.errLUA  = true
          event.log.err     = result
          errorCount = errorCount + 1
        end  

     ------------------------------ PORT ----------------------------------

        status, result = pcall(getDictonaryValue, event.log.Port, "ports")
        if status == true then -- проверка на исключение
          if result.status == true then
            event.log.PortNumber = result.value
          end
        else
          print("ERROR MainPort", result, "input", event.log.Port)
          event.log.errLUA  = true
          event.log.err     = result
          errorCount = errorCount + 1
        end  

     ------------------------------ PORTADD --------------------------------

        status, result = pcall(getDictonaryValue, event.log.SyncPort, "portsAdd")
        if status == true then -- проверка на исключение
          if result.status == true then
            event.log.SyncPortNumber = result.value
          end
        else
          print("ERROR AddPort", result, "input", event.log.SyncPort)
          event.log.errLUA  = true
          event.log.err     = result
          errorCount = errorCount + 1
        end  

     ------------------------- TRANSACTION STATUS --------------------------

        result = event.log.TransactionStatus
        if     result == "N" then event.log.TransactionStatusName = "Отсутствует"
        elseif result == "U" then event.log.TransactionStatusName = "Зафиксирована"
        elseif result == "R" then event.log.TransactionStatusName = "Не завершена"
        elseif result == "C" then event.log.TransactionStatusName = "Отменена"
        end
     
     ------------------------------ LEVEL -------------------------------------

        result = event.log.Level
        if debug == true then
          print("transform", "Level", result)
        end
        if     result == "I" then event.log.LevelName = "Информация"
        elseif result == "E" then event.log.LevelName = "Ошибка"
        elseif result == "W" then event.log.LevelName = "Предупреждение"
        elseif result == "N" then event.log.LevelName = "Примечание"
        end
        if debug == true then
          print("transform", "LevelName", event.log.LevelName)
        end

     --------------- TRANSACTION DATE, TRANSACTION NUMBER --------------------
        
        --local TransactionObj   = split(event.log.TransactionDate,",")
        --local transactionDate  = TransactionObj[1]
        --local transactionNumber= TransactionObj[2]
        --if transactionDate ~= "0" then
        --  event.log.TransactionDate   = math.ceil(startEpoch + (tonumber(transactionDate,16) / 10000))
        --  event.log.TransactionNumber = tonumber(transactionNumber,16)
        --else
        --  event.log.TransactionDate  = 0
        --end

     --------------------------------------------------------------------------

      emit(event)
end