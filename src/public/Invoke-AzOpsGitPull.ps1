function Invoke-AzOpsGitPull {

    [CmdletBinding()]
    [OutputType()]
    param ()

    begin {}

    process {
        Write-AzOpsLog -Level Information -Topic "git" -Message "Fetching latest changes"
        Start-AzOpsNativeExecution {
            git fetch
        } | Out-Host

        Write-AzOpsLog -Level Information -Topic "git" -Message "Checking for branch (system) existence"
        $branch = Start-AzOpsNativeExecution {
            git branch --remote | grep 'origin/system'
        } -IgnoreExitcode

        if ($branch) {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out existing branch (system)"
            Start-AzOpsNativeExecution {
                git checkout system
                git reset --hard origin/main
            } | Out-Host
        }
        else {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out new branch (system)"
            Start-AzOpsNativeExecution {
                git checkout -b system
            } | Out-Host
        }

        Write-AzOpsLog -Level Information -Topic "Invoke-AzOpsGitPull" -Message "Invoking refresh process"
        Invoke-AzOpsGitPullRefresh

        Write-AzOpsLog -Level Information -Topic "git" -Message "Adding azops file changes"
        Start-AzOpsNativeExecution {
            git add $env:AZOPS_STATE
        } | Out-Host

        Write-AzOpsLog -Level Information -Topic "git" -Message "Checking for additions / modifications / deletions"
        $status = Start-AzOpsNativeExecution {
            git status --short
        }

        if ($status) {
            $status -split ("`n") | ForEach-Object {
                Write-AzOpsLog -Level Information -Topic "git" -Message $_
            }

            Write-AzOpsLog -Level Information -Topic "git" -Message "Creating new commit"
            Start-AzOpsNativeExecution {
                git commit -m 'System commit'
            } | Out-Host

            Write-AzOpsLog -Level Information -Topic "git" -Message "Pushing new changes to origin"
            Start-AzOpsNativeExecution {
                git push --force origin system
            } | Out-Null

            switch ($env:SCMPLATFORM) {
                #region SCMPlatform GitHub
                "GitHub" {
                    Write-AzOpsLog -Level Information -Topic "rest" -Message "Checking if label (system) exists"
                    $params = @{
                        Uri     = ($env:GITHUB_API_URL + "/repos/" + $env:GITHUB_REPOSITORY + "/labels")
                        Headers = @{
                            "Authorization" = ("Bearer " + $env:GITHUB_TOKEN)
                        }
                    }
                    $response = Invoke-RestMethod -Method "Get" @params | Where-Object -FilterScript { $_.name -like "system" }

                    if (!$response) {
                        Write-AzOpsLog -Level Information -Topic "rest" -Message "Creating new label (system)"
                        $params = @{
                            Uri     = ($env:GITHUB_API_URL + "/repos/" + $env:GITHUB_REPOSITORY + "/labels")
                            Headers = @{
                                "Authorization" = ("Bearer " + $env:GITHUB_TOKEN)
                                "Content-Type"  = "application/json"
                            }
                            Body    = (@{
                                    "name"        = "system"
                                    "description" = "[AzOps] Do not delete"
                                    "color"       = "db9436"
                                } | ConvertTo-Json)
                        }
                        $response = Invoke-RestMethod -Method "Post" @params 
                    }

                    Write-AzOpsLog -Level Information -Topic "rest" -Message "Checking if pull request exists"
            

                    $params = @{
                        Uri     = ($env:GITHUB_API_URL + "/repos/" + $env:GITHUB_REPOSITORY + ("/pulls?state=open&head=") + $env:GITHUB_REPOSITORY + ":system")
                        Headers = @{
                            "Authorization" = ("Bearer " + $env:GITHUB_TOKEN)
                        }
                    }
                    $response = Invoke-RestMethod -Method "Get" @params 

                    if (!$response) {
                        Write-AzOpsLog -Level Information -Topic "gh" -Message "Creating new pull request"
                        Start-AzOpsNativeExecution {
                            gh pr create --title $env:GITHUB_PULL_REQUEST --body "Auto-generated PR triggered by Azure Resource Manager `nNew or modified resources discovered in Azure" --label "system" --repo $env:GITHUB_REPOSITORY
                        } | Out-Host
                    }
                    else {
                        Write-AzOpsLog -Level Information -Topic "gh" -Message "Skipping pull request creation"
                    }
                }
                #endregion
                #region SCMPlatform AzureDevOps
                "AzureDevOps" {
                    Write-AzOpsLog -Level Information -Topic "rest" -Message "Checking if pull request exists"

                    $params = @{
                        Uri     = "$($env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI)$($env:SYSTEM_TEAMPROJECTID)/_apis/git/repositories/$($env:BUILD_REPOSITORY_ID)/pullRequests?searchCriteria.sourceRefName=refs/heads/system&searchCriteria.targetRefName=refs/heads/main&searchCriteria.status=active&api-version=5.1"
                        Method  = "Get"
                        Headers = @{
                            "Authorization" = ("Bearer " + $env:SYSTEM_ACCESSTOKEN)
                            "Content-Type"  = "application/json"
                        }
                    }
                    Write-AzOpsLog -Level Verbose -Topic "rest" -Message "URI: $($params.Uri)"
                    $response = Invoke-RestMethod @params
                    Write-AzOpsLog -Level Verbose -Topic "rest" -Message "Pull request response count: $($response.count)"

                    if ($response.count -eq 0) {
                        Write-AzOpsLog -Level Information -Topic "rest" -Message "Creating new pull request"

                        $params = @{
                            Uri     = "$($env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI)$($env:SYSTEM_TEAMPROJECTID)/_apis/git/repositories/$($env:BUILD_REPOSITORY_ID)/pullRequests?api-version=5.1"
                            Method  = "Post"
                            Headers = @{
                                "Authorization" = ("Bearer " + $env:SYSTEM_ACCESSTOKEN)
                                "Content-Type"  = "application/json"
                            }
                            Body    = (@{
                                    "sourceRefName" = "refs/heads/system"
                                    "targetRefName" = "refs/heads/main"
                                    "title"         = "$env:GITHUB_PULL_REQUEST"
                                    "description"   = "Auto-generated PR triggered by Azure Resource Manager `nNew or modified resources discovered in Azure"
                                }  | ConvertTo-Json -Depth 5)
                        }
                        $response = Invoke-RestMethod @params

                        Write-AzOpsLog -Level Information -Topic "rest" -Message "Assigning pull request label"

                        $params = @{
                            Uri     = "$($env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI)$($env:SYSTEM_TEAMPROJECTID)/_apis/git/repositories/$($env:BUILD_REPOSITORY_ID)/pullRequests/$($response.pullRequestId)/labels?api-version=5.1-preview.1"
                            Method  = "Post"
                            Headers = @{
                                "Authorization" = ("Bearer " + $env:SYSTEM_ACCESSTOKEN)
                                "Content-Type"  = "application/json"
                            }
                            Body    = (@{
                                    "name" = "system"
                                }  | ConvertTo-Json -Depth 5)
                        }
                        Invoke-RestMethod @params
                    }
                }
                #endregion
                Default {
                    Write-AzOpsLog -Level Error -Topic "rest" -Message "Could not determine SCM platform from SCMPLATFORM. Current value is $env:SCMPLATFORM"
                }
            }
        }
    }

    end {}

}