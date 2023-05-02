local reaper = reaper
local r = reaper.ImGui_CreateContext("Load Envelope Points")

local file_browser_open = false
local file_path = ""

local function time_to_seconds(time_str)
    local h, m, s = time_str:match("(%d+):(%d+):(%d+%.%d+)")
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
end

local function parse_envelope_point(line)
    local position_str, value_str, shape_str, tension_str = line:match("position: (%S+), value: (%S+), shape: (%S+), tension: (%S+)")
    local position = time_to_seconds(position_str)
    local value = tonumber(value_str)
    local shape = tonumber(shape_str)
    local tension = tonumber(tension_str)
    return position, value, shape, tension
end

local function import_envelope_points(file_path)
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

            local point_count = reaper.CountEnvelopePoints(envelope)
            for i = point_count - 1, 0, -1 do
                local retval, position, value, shape, tension, selected = reaper.GetEnvelopePoint(envelope, i)
                if time_selection_start <= position and position <= time_selection_end then
                    reaper.DeleteEnvelopePointRange(envelope, time_selection_start, time_selection_end)
                    break
                end
            end

            local min_position, max_position = math.huge, -math.huge
            for line in file:lines() do
                local position = parse_envelope_point(line)
                if position then
                    min_position = math.min(min_position, position)
                    max_position = math.max(max_position, position)
                end
            end
            file:seek("set", 0) 

            local file_length = max_position - min_position
            local time_selection_length = time_selection_end - time_selection_start
            for line in file:lines() do
                local position, value, shape, tension = parse_envelope_point(line)
                if position and value and shape and tension then
                    local normalized_position = (position - min_position) / file_length
                    local scaled_position = time_selection_start + (normalized_position * time_selection_length)
                    reaper.InsertEnvelopePoint(envelope, scaled_position, value, shape, tension, true, true)
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
    local visible, open = reaper.ImGui_Begin(r, "Load Envelope Points", true, reaper.ImGui_WindowFlags_AlwaysAutoResize())

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
            import_envelope_points(file_path)
        end

        reaper.ImGui_Text(r, "File path: " .. file_path)
    end

    reaper.ImGui_End(r)

    if open then
        reaper.defer(load_envelope_points_dialog)
    else
        reaper.ImGui_DestroyContext(r)
    end
end

load_envelope_points_dialog()


