local reaper = reaper
local r = reaper.ImGui_CreateContext("Load Envelope Points")
local add_value = 0.0
local file_browser_open = false
local file_path = ""
local repeat_count = 1
local min_value_percentage = 0
local max_value_percentage = 100
local resize_points = false

local function time_to_seconds(time_str)
    local h, m, s = time_str:match("(%d+):(%d+):(%d+%.%d+)")
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
end

local function parse_envelope_point(line)
    local position_str, value, shape, tension = line:match("position:%s*(.-),%s*value:%s*(.-),%s*shape:%s*(.-),%s*tension:%s*(.*)")
    if position_str and value and shape and tension then
        local position = reaper.parse_timestr_pos(position_str, 0)
        return position, tonumber(value), tonumber(shape), tonumber(tension)
    end
    return nil
end

local function import_envelope_points(file_path, repeat_count, min_value_percentage, max_value_percentage, resize_points)
    local time_selection_start, time_selection_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local envelope = reaper.GetSelectedTrackEnvelope(0)

    if not envelope then
        reaper.ShowConsoleMsg("No selected track envelope.\n")
    else
        local file = io.open(file_path, "r")

        if not file then
            reaper.ShowMessageBox("Failed to open the file. Check the path and try again.", "Error", 0)
        else
            reaper.Undo_BeginBlock()

            local min_position, max_position = math.huge, -math.huge
            local last_position = time_selection_start

            for line in file:lines() do
                local position, value, shape, tension = parse_envelope_point(line)
                if position then
                    min_position = math.min(min_position, position)
                    max_position = math.max(max_position, position)
                end
            end
            

            local range = time_selection_end - time_selection_start
            local width_scale = resize_points and range / (max_position - min_position) or 1

            local delete_range = resize_points and range * repeat_count or (max_position - min_position) * repeat_count

            reaper.DeleteEnvelopePointRange(envelope, time_selection_start, time_selection_start + delete_range)

            for _ = 1, repeat_count do
                file:seek("set", 0)
                for line in file:lines() do
                    local position, value, shape, tension = parse_envelope_point(line)
                    if position then
                        if resize_points then
                            position = (position - min_position) * width_scale + last_position
                        else
                            position = position - min_position + last_position
                        end

                        value = value * (max_value_percentage / 100) + add_value

                        reaper.InsertEnvelopePoint(envelope, position, value, shape, tension, false, true)
                    end
                end
                if resize_points then
                    last_position = last_position + range
                else
                    last_position = last_position + (max_position - min_position)
                end
            end


            reaper.Envelope_SortPoints(envelope)
            reaper.Undo_EndBlock("Import and fit envelope points from " .. file_path, -1)
            reaper.UpdateArrange()

            file:close()
            return true
        end
    end
end

local function load_envelope_points_dialog()
    local visible, open = reaper.ImGui_Begin(r, "Load Envelope Curve", true, reaper.ImGui_WindowFlags_AlwaysAutoResize())
    
    if visible then
        if reaper.ImGui_Button(r, "Load") then
            local resource_path = reaper.GetResourcePath()
            local initial_dir = resource_path .. "/Envelopes/"
            local browser_retval, browser_path = reaper.GetUserFileNameForRead(initial_dir, "Select a .reaperenvelope file", ".reaperenvelope")
            if browser_retval then
                file_path = browser_path
            end
        end

        reaper.ImGui_SameLine(r)
        if reaper.ImGui_Button(r, "Apply") and file_path ~= "" then
            import_envelope_points(file_path, repeat_count, min_value_percentage, max_value_percentage, resize_points)
        end

        reaper.ImGui_Text(r, "File path: " .. file_path)

        local changed, new_repeat_count = reaper.ImGui_InputInt(r, "Repeat Count(Integer)", repeat_count)
        if changed then
            repeat_count = math.max(1, new_repeat_count) 
        end


        local changed_add, new_add_value = reaper.ImGui_InputDouble(r, "Add Value(-1000 to 1000)", add_value, 0.1, 1)
        if changed_add then
            add_value = math.max(-1000, math.min(new_add_value, 1000)) 
        end

        local changed_max, new_max_value_percentage = reaper.ImGui_InputDouble(r, "Max Velocity Multiply (0 to 1000%)", max_value_percentage)
        if changed_max then
            max_value_percentage = math.max(0, math.min(new_max_value_percentage, 1000)) 
        end
        
        local changed_resize, new_resize_points = reaper.ImGui_Checkbox(r, "Fit to Range", resize_points)
        if changed_resize then
            resize_points = new_resize_points 
        end

    end

    reaper.ImGui_End(r)

    if open then
        reaper.defer(load_envelope_points_dialog)
    else
        reaper.ImGui_DestroyContext(r)
    end
end

load_envelope_points_dialog()

