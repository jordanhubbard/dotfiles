#!/usr/bin/env wish

#
# worldclock.sh - Display world clock with multiple timezones
#
# This Tk/Tcl script displays a graphical world clock showing time
# in multiple timezones with proper DST handling.
#

package require Tk

# Configuration: Add or modify cities here
# Format: {Display_Name Timezone}
set cities {
    {"London" "Europe/London"}
    {"New York" "America/New_York"}
    {"Los Angeles" "America/Los_Angeles"}
    {"Taipei" "Asia/Taipei"}
}

# Function to get the time for a specific timezone
proc update_time {label_name timezone} {
    # Get current time in the specified timezone
    set current_time [clock seconds]
    
    # Format time with proper timezone handling (includes DST)
    set time_str [clock format $current_time -timezone :$timezone -format "%Y-%m-%d %H:%M:%S"]
    set tz_abbr [clock format $current_time -timezone :$timezone -format "%Z"]
    
    # Update the label with formatted time and timezone abbreviation
    $label_name configure -text "$time_str ($tz_abbr)"
}

# Function to update all clocks every second
proc update_clocks {} {
    global cities
    
    # Update each city's time
    foreach city $cities {
        set name [lindex $city 0]
        set tz [lindex $city 1]
        set safe_name [string map {" " "_"} [string tolower $name]]
        update_time .label_${safe_name}_time $tz
    }
    
    # Schedule the next update in 1000ms (1 second)
    after 1000 update_clocks
}

# Create the main window
wm title . "World Clock"

# Set window properties
wm resizable . 1 0

# Create header
label .header -text "World Clock" -font {Helvetica 28 bold} -fg "#2c3e50"
grid .header -row 0 -column 0 -columnspan [llength $cities] -pady 10 -sticky ew

# Create a frame for the clocks
frame .clocks -bg "#ecf0f1"
grid .clocks -row 1 -column 0 -sticky nsew -padx 10 -pady 10

# Configure grid weights for responsive layout
grid columnconfigure . 0 -weight 1
grid rowconfigure . 1 -weight 1

# Create labels for each city
set col 0
foreach city $cities {
    set name [lindex $city 0]
    set tz [lindex $city 1]
    set safe_name [string map {" " "_"} [string tolower $name]]
    
    # Create a frame for this city
    frame .clocks.${safe_name} -bg "#ffffff" -relief raised -borderwidth 2
    grid .clocks.${safe_name} -row 0 -column $col -padx 10 -pady 10 -sticky nsew
    
    # City name label
    label .clocks.${safe_name}.title -text $name \
        -font {Helvetica 20 bold} \
        -bg "#3498db" \
        -fg "#ffffff" \
        -relief flat \
        -padx 10 \
        -pady 5
    pack .clocks.${safe_name}.title -fill x
    
    # Time label
    label .label_${safe_name}_time -text "" \
        -font {Courier 14} \
        -bg "#ffffff" \
        -fg "#2c3e50" \
        -justify center \
        -padx 10 \
        -pady 10
    pack .label_${safe_name}_time -in .clocks.${safe_name} -fill both -expand 1
    
    # Configure column weight for responsive layout
    grid columnconfigure .clocks $col -weight 1
    
    incr col
}

# Add footer with instructions
label .footer -text "Press Ctrl+C or close window to exit" \
    -font {Helvetica 10 italic} \
    -fg "#7f8c8d"
grid .footer -row 2 -column 0 -columnspan [llength $cities] -pady 5

# Set minimum window size
wm minsize . [expr {250 * [llength $cities]}] 200

# Center window on screen
update idletasks
set width [winfo reqwidth .]
set height [winfo reqheight .]
set x [expr {([winfo screenwidth .] - $width) / 2}]
set y [expr {([winfo screenheight .] - $height) / 2}]
wm geometry . +$x+$y

# Start the clock update
update_clocks

# Bind escape key to quit
bind . <Control-c> {exit}
bind . <Escape> {exit}

