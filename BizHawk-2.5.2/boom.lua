--[[
    @author TheMaverickProgrammer
    @github https://github.com/TheMaverickProgrammer/boomsheetslua
    @module boom
    @date 1/23/2021
    @description This is a lua port of the boomsheet animation file format for 2D spritesheets

    @example
    ```
    anim = boom.load(path)        -- loads the animation from path and stores it in the anim table
    t    = anim:duration(state)   -- returns the duration of the animation state in seconds
    f    = anim:refresh(state)    --  sets `elapsed` to zero and applies the first frame from that state
    f    = anim:update(state,sec) -- updates animation by seconds elapsed and returns the frame

    print(anim.imagePath) -- prints the image path
    print(anim.elapsed)   -- the elapsed time for this animation
    curr = anim.currFrame -- can also access the current frame this way
    
    anim.states.ATTACK_PUNCH.loop = true -- tells this animation state to loop (default false)
    ```
--]]

local boom = {}

-- Load a *.animation file at `path`. Return true if parsing was successful, false otherwise.
function boom.load(path)
    -- animations keep a list of all states, elapsed time, image path, 
    -- and the lookup for the recent frame
    local animation = {states={},elapsed=0,imagePath="",currFrame={}}

    -- @return result of removed quotes in input string
    function cleanstr(str)
        str, _ = str:gsub('\"', '')
        return str
    end

    -- @return the total duration of an anim state in seconds
    function animation.duration(self, state)
        local time = 0
        for _,frame in ipairs(self.states[state].framelist) do
            time = time + frame.duration
        end
        return time
    end

    -- update the current frame and reset the timer over to zero
    -- @return updated frame `currFrame`
    function animation.refresh(self, state)
        self.elapsed = 0
        return animation.update(self, state, 0)
    end

    -- update the animation state by elapsed seconds
    -- @return updated frame `currFrame`
    function animation.update(self, state, seconds)
        local currState = self.states[state]
        self.elapsed = self.elapsed + seconds

        local duration = self:duration(state)

        if self.elapsed > duration then
            self.elapsed = duration
        end

        local e = self.elapsed 
        local index = 1

        while e > 0 and index <= #currState.framelist do 
            e = e - currState.framelist[index].duration
            index = index + 1

            if index > #currState.framelist then
                if currState.loop then
                    index = 1
                    self.elapsed = self.elapsed - duration
                else
                    index = index - 1
                end
            end
        end

        local currFrame = currState.framelist[index]
        
        -- copy values over to lookup table
        for k,v in pairs(currFrame) do
            self.currFrame[k] = v
        end

        return self.currFrame
    end

    -- extract the contents of the file
    local file = io.open(path, "rb")
    if not file then 
        -- failed to open? return nil
        return nil
    else
        -- otherwise, close
        file:close()
    end

    local currState = ""

    -- for each line, tokenize everything between spaces
    for line in io.lines(path) do
        local tokens = {}
        for token in line:gmatch("([^%s]+)%s*") do
            table.insert(tokens, token)
        end

        local key = tokens[1]
        local imagePathKey = nil
        
        if key then 
            imagePathKey = key:sub(0,9)
        end
        
        -- most keys have attributes in the form of "key=value"
        -- some keys like "imagePath" are directly assigned to their value
        if  imagePathKey == "imagePath" then
            animation.imagePath = cleanstr(key:sub(11))
        elseif key == "animation" then 
            -- add a new state table to our animation
            local attrs = {}
            for token in tokens[2]:gmatch("([^=]+)") do
                table.insert(attrs, token)
            end

            if not attrs[2] then 
                return nil -- malformed
            end

            currState = cleanstr(attrs[2])

            -- prepopulate our state table with framelist and set looping to false
            animation.states[currState] = {framelist={},loop=false}
        elseif key == "frame" then
            -- remove the key, we already accounted for it
            table.remove(tokens, 1)

            -- construct new frame data
            local frame = {}
            for _, v in ipairs(tokens) do
                -- string.gmatch() doesn't return a counter or iterator
                -- so we must toggle whether our first token was the key
                -- or the value...
                local is_key = true
                local last_key = nil -- track the key
                for token in v:gmatch("([^=]+)") do
                    if is_key then
                        last_key = cleanstr(token)
                    else
                        -- extract token value between quotes
                        local value = tonumber(cleanstr(token))

                        -- set the table
                        frame[last_key] = value
                    end
                    is_key = not is_key -- toggle flag
                end
            end
            -- add this new frame into our animation state's frame list
            table.insert(animation.states[currState].framelist, frame)
        end 
    end

    -- return the fully constructed animation object
    return animation
end

-- export module
return boom