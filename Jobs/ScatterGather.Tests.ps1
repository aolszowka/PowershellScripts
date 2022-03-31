function ScatterGather {
    [CmdletBinding()]
    param (
        [int]$NumberOfJobs = 20
    )
    
    process {
        Write-Host "Spinning up Processes"
        # Scatter
        for ($i = 0; $i -lt $NumberOfJobs; $i++) {
            Start-Job -ScriptBlock {
                # Simulate the process taking some random amount of time
                $sleepSeconds = ($using:i % 10) + 10
                [System.Threading.Thread]::Sleep($sleepSeconds * 1000)

                # Every 3rd process will fail
                if ($using:i % 3 -eq 0) {
                    return [PSCustomObject]@{
                        Result  = "Failure"
                        Message = "Original Triggered Job $using:i. Slept for $sleepSeconds seconds"
                    }
                }
                else {
                    return [PSCustomObject]@{
                        Result  = "Success"
                        Message = "Original Triggered Job $using:i. Slept for $sleepSeconds seconds"
                    }
                }
            } | Out-Null
        }
        Write-Host "Done Spinning up Processes"

        # Gather - This will happen sequentially again
        Write-Host "Processing"
        $numberOfProcessedJobs = 0
        $numberOfRetryJobs = 0
        while ($null -ne (Get-Job)) {
            $numberOfProcessedJobs++
            # First find a job that is "done"
            $doneJob = Get-Job | Wait-Job -Any

            # Now get the results of the job and remove it from the queue
            $processResult = $doneJob | Receive-Job -AutoRemoveJob -Wait

            # Error handling for the above
            if ($null -eq $processResult) {
                throw "The background job returned no results this is unexpected"
            }

            Write-Host "$($processResult.Result) - $($processResult.Message)"

            if ($processResult.Result -eq 'Failure') {
                $numberOfRetryJobs++
                # Simulate a process that will "fix" the failure
                Start-Job -ScriptBlock {
                    $sleepSeconds = 8
                    [System.Threading.Thread]::Sleep($sleepSeconds * 1000)
                    return [PSCustomObject]@{
                        Result  = "Success"
                        Message = "Retry Job Number $using:numberOfRetryJobs"
                    }
                } | Out-Null
            }
        }

        Write-Host "Done Processing; Processed $numberOfProcessedJobs jobs"
    }
}

ScatterGather