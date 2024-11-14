#!/opt/local/bin/wish
package require Tk

# Function to get the time for a specific timezone offset and update the label
proc update_time {label_name offset} {
    # Calculate the time for the given timezone offset
    set current_time [clock seconds]
    set time_in_zone [clock format [expr {$current_time + $offset * 3600}] -format "%Y-%m-%d %H:%M:%S"]
    
    # Update the label with the formatted time
    $label_name configure -text $time_in_zone
}

# Function to update all clocks every second
proc update_clocks {} {
    update_time .label_london 0     ;# London (UTC+0)
    update_time .label_newyork -5   ;# New York (UTC-5)
    update_time .label_la -8        ;# Los Angeles (UTC-8)
    update_time .label_taipei 8     ;# Taipei (UTC+8)

    # Schedule the next update in 1000ms (1 second)
    after 1000 update_clocks
}

# Create the main window
wm title . "World Clock"

# Create labels for each city
label .label_london_title -text "London" -font {Helvetica 24 bold}
label .label_newyork_title -text "New York" -font {Helvetica 24 bold}
label .label_la_title -text "Los Angeles" -font {Helvetica 24 bold}
label .label_taipei_title -text "Taipei" -font {Helvetica 24 bold}

label .label_london -text "" -font {Helvetica 18}
label .label_newyork -text "" -font {Helvetica 18}
label .label_la -text "" -font {Helvetica 18}
label .label_taipei -text "" -font {Helvetica 18}

# Arrange the labels in a grid layout
grid .label_london_title -row 0 -column 0 -padx 10 -pady 5
grid .label_london -row 1 -column 0 -padx 10 -pady 5
grid .label_newyork_title -row 0 -column 1 -padx 10 -pady 5
grid .label_newyork -row 1 -column 1 -padx 10 -pady 5
grid .label_la_title -row 0 -column 2 -padx 10 -pady 5
grid .label_la -row 1 -column 2 -padx 10 -pady 5
grid .label_taipei_title -row 0 -column 3 -padx 10 -pady 5
grid .label_taipei -row 1 -column 3 -padx 10 -pady 5

# Start the clock update
update_clocks

