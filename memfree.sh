#!/usr/bin/env fish

# Print a message when the script starts
echo "Starting memfree"

while true
    # Get the free memory percentage from the 'free' command and extract the integer part
    set free_mem_percentage (sudo free | grep Mem | awk '{print $4/$2 * 100.0}' | cut -d. -f1)

    # Check if free memory is less than 10%
    if [ $free_mem_percentage -lt 10 ]
        # Capture the amount of free memory before cleaning
        set pre_free_mem (sudo free | grep Mem | awk '{print $4}')

        # Print message indicating low memory and cache clearing
        echo "Mem went below 10%, cleaning..."

        # Run the cache clearing commands
        sudo sh -c 'free && sync && echo 3 > /proc/sys/vm/drop_caches && free'

        # Capture the amount of free memory after cleaning
        set post_free_mem (sudo free | grep Mem | awk '{print $4}')

        # Calculate the amount of memory restored (in kB)
        set memory_restored (math $post_free_mem - $pre_free_mem)

        # Convert the restored memory to GB (by dividing by 1024^2)
        set memory_restored_gb (math $memory_restored / 1024 / 1024)

        # Print the amount of memory restored
        echo "Mem went below 10%, cleaned. $memory_restored_gb GB has been restored."
    end

    # Sleep for a while (e.g., check every 30 seconds)
    sleep 30
end
