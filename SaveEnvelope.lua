local reaper = reaper
local r = reaper.ImGui_CreateContext("Save Envelope Points")

local folder_path = reaper.GetResourcePath() .. "/Envelopes/"
local file_name = "test.reaperenvelope"
local save_button_pressed = false

local function format_time(seconds)
    local h = math.floor(seconds / 3600)
    local remainder = seconds % 3600
    local m = math.floor(remainder / 60)
    local s = remainder % 60
    return string.format("%02d:%02d:%06.3f", h, m, s)
end

local function save_envelope_points(folder_path, file_name)
    local time_selection_start, time_selection_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

    if time_selection_start == time_selection_end then
        reaper.ShowMessageBox("No time selection.", "Error", 0)
    else
        local envelope = reaper.GetSelectedTrackEnvelope(0)
        local point_count = reaper.CountEnvelopePoints(envelope)

        local envelope_points = {}

        for i = 0, point_count - 1 do
            local retval, position, value, shape, tension, selected = reaper.GetEnvelopePoint(envelope, i)
            if time_selection_start <= position and position <= time_selection_end then
                local relative_position = position - time_selection_start
                table.insert(envelope_points, {
                    position = relative_position,
                    value = value,
                    shape = shape,
                    tension = tension,
                    selected = selected
                })
            end
        end

        local file_path = folder_path .. "/" .. file_name
        local file = io.open(file_path, "w")
        if file then
            for _, point in ipairs(envelope_points) do
                file:write("position: " .. format_time(point.position) .. ", value: " .. point.value .. ", shape: " .. point.shape .. ", tension: " .. point.tension .. "\n")
            end
            file:close()
            return true
        else
            reaper.ShowMessageBox("Failed to open the file. Check the path and try again.", "Error", 0)
            return false
        end
    end
end


local function envelope_points_saver()
    local visible, open = reaper.ImGui_Begin(r, "Save Envelope Points", true, reaper.ImGui_WindowFlags_AlwaysAutoResize())

    if visible then
        reaper.ImGui_Text(r, "Folder:")
        local input_updated, new_folder_path = reaper.ImGui_InputText(r, "##FolderName", folder_path, reaper.ImGui_InputTextFlags_EnterReturnsTrue())
        if input_updated then
            folder_path = new_folder_path
        end
        
        if reaper.ImGui_Button(r, "Browse...") then
            local browser_retval, browser_path = reaper.JS_Dialog_BrowseForFolder("Select a folder", folder_path)
            if browser_retval then
                folder_path = browser_path
            end
        end

        reaper.ImGui_Text(r, "File name:")
        local input_updated, new_file_name = reaper.ImGui_InputText(r, "##FileName", file_name, reaper.ImGui_InputTextFlags_EnterReturnsTrue())
        if input_updated then
            file_name = new_file_name
        end

        if reaper.ImGui_Button(r, "Save") then
            save_button_pressed = save_envelope_points(folder_path, file_name)
            if save_button_pressed then
                reaper.ShowMessageBox("Directory: " .. folder_path .. "\n" .. file_name .. "\nSAVED!!", "Save Successful", 0)
                open = false
            end
        end
    end

    reaper.ImGui_End(r)

    if open and not save_button_pressed then
        reaper.defer(envelope_points_saver)
    else
        reaper.ImGui_DestroyContext(r)
    end
end

envelope_points_saver()

