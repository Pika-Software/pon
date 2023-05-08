--[[

    DEVELOPMENTAL VERSION

    VERSION 1.2.2
    Copyright thelastpenguin™

    You may use this for any purpose as long as:
    - You don't remove this copyright notice.
    - You don't claim this to be your own.
    - You properly credit the author, thelastpenguin™, if you publish your work based on (and/or using) this.

    If you modify the code for any purpose, the above still applies to the modified code.
    The author is not held responsible for any damages incured from the use of pon, you use it at your own risk.

]]

-- Libraries
local string = string
local table = table

-- Variables
local logger = gpm.Logger
local tonumber = tonumber
local Entity = Entity
local Vector = Vector
local Angle = Angle
local type = type
local next = next

-- TODO: Remove `package.seeall` in future
module( "pon", package.seeall )

-- encode
do

    local meta = {}
    meta.__index = meta

    local cacheSize = 0

    -- Table encode
    meta["table"] = function( tbl, cache )
        local output = {}
        if cache[tbl] then
            output[#output + 1] = string.format( "(%x)", cache[tbl] )
            return
        end

        cacheSize = cacheSize + 1
        cache[tbl] = cacheSize

        local first = next( tbl, nil )
        local predictedNumeric = 1

        -- starts with a numeric dealio
        if first == 1 then
            output[#output + 1] = "{"

            for k, v in next, tbl do
                if k ~= predictedNumeric then break end
                predictedNumeric = predictedNumeric + 1

                local tv = type( v )
                if tv == "string" then
                    local pid = cache[v]
                    if pid then
                        output[#output + 1] = string.format("(%x)", pid)
                    else
                        cacheSize = cacheSize + 1
                        cache[v] = cacheSize
                        output[#output + 1] = meta.string( v, output, cache )
                    end
                else
                    output[#output + 1] = meta[tv]( v, output, cache )
                end
            end

            predictedNumeric = predictedNumeric - 1
        else
            predictedNumeric = nil
        end

        if predictedNumeric == nil then
            output[#output + 1] = "[" -- no array component
        else
            output[#output + 1] = "~" -- array component came first so shit needs to happen
        end

        for k, v in next, tbl, predictedNumeric do
            local tk, tv = type( k ), type( v )

            -- WRITE KEY
            if tk == "string" then
                local pid = cache[k]
                if pid then
                    output[#output + 1] = string.format("(%x)",  pid )
                else
                    cacheSize = cacheSize + 1
                    cache[k] = cacheSize

                    output[#output + 1] = meta.string( k, output, cache )
                end
            else
                output[#output + 1] = meta[tk]( k, output, cache)
            end

            -- WRITE VALUE
            if tv == "string" then
                local pid = cache[v]
                if pid then
                    output[#output + 1] = string.format("(%x)",  pid )
                else
                    cacheSize = cacheSize + 1
                    cache[v] = cacheSize

                    output[#output + 1] = meta.string( v, output, cache )
                end
            else
                output[#output + 1] = meta[tv]( v, output, cache )
            end
        end

        output[#output + 1] = "}"
        return table.concat( output )
    end

    -- String encode
    meta["string"] = function( str )
        local estr, count = string.gsub( str, ";", "\\;")
        if count ~= 0 then
            return "\"" .. estr .. "\";"
        end

        return "\'" .. str .. ";"
    end

    -- Number encode
    meta["number"] = function( number )
        if number % 1 ~= 0 then
            return tonumber( number ) .. ";"
        end

        if number < 0 then
            return string.format( "x%x;", -number )
        end

        return string.format( "X%x;", number )
    end

    -- Boolean encode
    meta["boolean"] = function( boolean )
        return boolean and "t" or "f"
    end

    -- Vector encode
    meta["Vector"] = function( vector )
        return "V" .. vector[1] .. "," .. vector[2] .. "," .. vector[3] .. ";"
    end

    -- Angle encode
    meta["Angle"] = function( angle )
        return "A" .. angle[1] .. "," .. angle[2] .. "," .. angle[3] .. ";"
    end

    -- Entity encode
    meta["Entity"] = function( entity )
        return "E" .. ( IsValid( entity ) and ( entity:EntIndex() .. ";" ) or "#" )
    end

    -- Aliases of entity
    meta["Vehicle"] = meta["Entity"]
    meta["NextBot"] = meta["Entity"]
    meta["PhysObj"] = meta["Entity"]
    meta["Player"] = meta["Entity"]
    meta["Weapon"] = meta["Entity"]
    meta["NPC"] = meta["Entity"]

    -- Nil encode
    meta["nil"] = function()
        return "?"
    end

    function meta:__call( value, compress )
        cacheSize = 0

        local valueType = type( value )
        local encoder = self[valueType]
        if type( encoder ) ~= "function" then
            ErrorNoHaltWithStack( "Type: `" .. valueType .. "` can not be encoded. Encoded as as pass-over value." )
            encoder = self["nil"]
        end

        return self[valueType]( value, {} )
    end

    encode = setmetatable( {}, meta )

end

-- decode
do

    local meta = {}
    meta.__index = meta

    meta["{"] = function( index, str, cache )

        local cur = {}
        cache[#cache + 1] = cur

        local k, v, tk, tv = 1, nil, nil, nil
        while true do
            tv = string.sub( str, index, index )
            if not tv or tv == "~" then
                index = index + 1
                break
            end

            if tv == "}" then
                return index + 1, cur
            end

            -- READ THE VALUE
            index = index + 1
            index, v = meta[tv]( index, str, cache )
            cur[k] = v

            k = k + 1
        end

        while true do
            tk = string.sub( str, index, index )
            if not tk or tk == "}" then
                index = index + 1
                break
            end

            -- READ THE KEY
            index = index + 1
            index, k = meta[tk]( index, str, cache )

            -- READ THE VALUE
            tv = string.sub( str, index, index )
            index = index + 1
            index, v = meta[tv]( index, str, cache )

            cur[k] = v
        end

        return index, cur
    end

    meta["["] = function( index, str, cache )
        local cur = {}
        cache[#cache + 1] = cur

        local k, v, tk, tv = 1, nil, nil, nil
        while true do
            tk = string.sub( str, index, index )
            if not tk or tk == "}" then
                index = index + 1
                break
            end

            -- READ THE KEY
            index = index + 1
            index, k = meta[tk]( index, str, cache )
            if not k then continue end

            -- READ THE VALUE
            tv = string.sub( str, index, index )
            index = index + 1

            if not meta[tv] then
                logger:Warn( "did not find type: %s", tv )
            end

            index, v = meta[tv]( index, str, cache )

            cur[k] = v
        end

        return index, cur
    end

    -- STRING
    meta["\""] = function( index, str, cache )
        local finish = string.find( str, "\";", index, true )
        local res = string.gsub( string.sub( str, index, finish - 1 ), "\\;", ";" )
        index = finish + 2

        cache[#cache + 1] = res
        return index, res
    end

    -- STRING NO ESCAPING NEEDED
    meta["\'"] = function( index, str, cache )
        local finish = string.find( str, ";", index, true )
        local res = string.sub( str, index, finish - 1 )
        index = finish + 1

        cache[#cache + 1] = res
        return index, res
    end

    -- NUMBER
    meta["n"] = function( index, str, cache )
        index = index - 1
        local finish = string.find( str, ";", index, true )
        local num = tonumber( string.sub( str, index, finish - 1 ) )
        index = finish + 1
        return index, num
    end

    meta["0"] = meta["n"]
    meta["1"] = meta["n"]
    meta["2"] = meta["n"]
    meta["3"] = meta["n"]
    meta["4"] = meta["n"]
    meta["5"] = meta["n"]
    meta["6"] = meta["n"]
    meta["7"] = meta["n"]
    meta["8"] = meta["n"]
    meta["9"] = meta["n"]
    meta["-"] = meta["n"]

    -- positive hex
    meta["X"] = function( index, str, cache )
        local finish = string.find( str, ";", index, true )
        local num = tonumber( string.sub( str, index, finish - 1), 16 )
        index = finish + 1
        return index, num
    end

    -- negative hex
    meta["x"] = function( index, str, cache )
        local finish = string.find( str, ";", index, true )
        local num = -tonumber( string.sub( str, index, finish - 1), 16 )
        index = finish + 1
        return index, num
    end

    -- POINTER
    meta["("] = function( index, str, cache )
        local finish = string.find( str, ")", index, true )
        local num = tonumber( string.sub( str, index, finish - 1), 16 )
        index = finish + 1
        return index, cache[num]
    end

    -- BOOLEAN. ONE DATA TYPE FOR YES, ANOTHER FOR NO.
    meta["t"] = function( index )
        return index, true
    end

    meta["f"] = function( index )
        return index, false
    end

    -- VECTOR
    meta["V"] = function( index, str, cache )
        local finish = string.find( str, ";", index, true )
        local vecStr = string.sub( str, index, finish - 1 )
        index = finish + 1; -- update the index.
        local segs = string.Explode( ",", vecStr, false )
        return index, Vector( tonumber( segs[1] ), tonumber( segs[2] ), tonumber( segs[3] ) )
    end

    -- ANGLE
    meta["A"] = function( index, str, cache )
        local finish = string.find( str, ";", index, true )
        local angStr = string.sub( str, index, finish - 1 )
        index = finish + 1; -- update the index.

        local segs = string.Explode( ",", angStr, false )
        return index, Angle( tonumber( segs[1] ), tonumber( segs[2] ), tonumber( segs[3] ) )
    end

    -- ENTITY
    meta["E"] = function( index, str )
        if str[index] == "#" then
            index = index + 1
            return index, NULL
        end

        local finish = string.find( str, ";", index, true )
        local num = tonumber( string.sub( str, index, finish - 1 ) )
        index = finish + 1
        return index, Entity( num )
    end

    -- PLAYER
    meta["P"] = function( index, str )
        local finish = string.find( str, ";", index, true )
        local num = tonumber( string.sub( str, index, finish - 1 ) )
        index = finish + 1

        return index, Entity( num ) or NULL
    end

    -- NIL
    meta["?"] = function( index )
        return index + 1, nil
    end

    function meta:__call( str, decompress )
        local typeKey = string.sub( str, 1, 1 )
        local decoder = self[typeKey]
        if type( decoder ) ~= "function" then
            ErrorNoHaltWithStack( "Key: `" .. typeKey .. "` can not be decoded. Decoded as as pass-over value." )
            typeKey = "?"
        end

        local _, value = self[typeKey]( 2, str, {} )
        return value
    end

    decode = setmetatable( {}, meta )

end

-- local encoded = encode( "hello" )

-- print( "encoded", encoded )

-- local decoded = decode( encoded )

-- print( "decoded", decoded )