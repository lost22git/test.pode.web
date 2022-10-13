Import-Module Pode.Web

Start-PodeServer {
  # 添加一个 http 监听端点
  Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

  # 使用 PodeWeb 模板
  Use-PodeWebTemplates -Title "资源监控" -Theme Light

  # 导航栏下拉菜单
  $navDropdown = New-PodeWebNavDropdown -Name 'Social' -Icon 'forum-outline' -Items @(
    New-PodeWebNavLink -Name 'Twitter' -Url 'https://twitter.com' -Icon 'twitter' -NewTab
    New-PodeWebNavLink -Name 'Facebook' -Url 'https://facebook.com' -Icon 'facebook' -NewTab
    New-PodeWebNavDivider
    New-PodeWebNavLink -Name 'YouTube' -Url 'https://youtube.com' -Icon 'youtube' -NewTab
    New-PodeWebNavLink -Name 'Twitch' -Url 'https://twitch.tv' -Icon 'twitch' -NewTab
  )
  Set-PodeWebNavDefault -Items $navDropdown

  # Processes 页面
  Add-PodeWebPage -Name "Processes" -Icon "gauge" -Layouts @(
    # 表格
    New-PodeWebTable -Name "Processes" -AsCard -Filter -Paginate -PageSize 8 -ScriptBlock{
      $filter = $WebEvent.Data.Filter
      $filter = $filter -eq $null ? "" : $filter.Trim()
      $pageIndex = [int]$WebEvent.Data.PageIndex
      $pageSize = [int]$WebEvent.Data.PageSize
      $pageIndex = $pageIndex -lt 1 ? 1 : $pageIndex
      $skip = ($pageIndex-1)*$pageSize

      Write-Host "[Processes] pageIndex=$pageIndex pageSize=$pageSize skip=$skip"

      $data = foreach($p in (Get-Process | Where-Object {$_.Name.Contains($filter)} | Sort-Object PrivateMemorySize -Descending | Select-Object -Skip $skip -First $pageSize))
      {
        [ordered]@{
          Name = $p.Name
          Pid = $p.Id
          ThreadCount = $p.Threads.Count
          CPU = $p.CPU
          PrivateMemorySize = $p.PrivateMemorySize
          VirtualMemorySize =$p.VirtualMemorySize
          StartTime = $p.StartTime.ToString()
          #CommandLine = $p.CommandLine
        }
      }

      $data | Update-PodeWebTable -Name 'Processes' -PageIndex $pageIndex -TotalItemCount 1000
    } -Columns @(
      Initialize-PodeWebTableColumn -Key PrivateMemorySize -Alignment Center -Icon "memory"
      Initialize-PodeWebTableColumn -Key VirtualMemorySize -Alignment Center -Icon "memory"
      Initialize-PodeWebTableColumn -Key CPU -Alignment Center -Icon "cpu-64-bit"
      Initialize-PodeWebTableColumn -Key StartTime -Alignment Center -Icon "calendar-clock"
    )

    # 折线图
    New-PodeWebChart -Name 'Top CPU Usage' -Type line -AutoRefresh -AsCard -ScriptBlock {
      Get-Process |
        Sort-Object -Property CPU -Descending |
        Select-Object -First 10 |
        Select-Object  @{ Name="Name"; Expression={"$($_.ProcessName)($($_.Id))"} },CPU,PrivateMemorySize |
        ConvertTo-PodeWebChartData  -LabelProperty Name -DatasetProperty CPU,PrivateMemorySize
    }

    # 柱状图
    New-PodeWebChart -Name 'Top Memory Usage' -Type bar -AutoRefresh -AsCard -ScriptBlock{
      Get-Process |
        Sort-Object -Property PrivateMemorySize -Descending |
        Select-Object -First 10 |
        Select-Object  @{ Name="Name"; Expression={"$($_.ProcessName)($($_.Id))"} }, @{Name="内存使用";Expression={ "{0:N2}" -f $_.PrivateMemorySize/1024/1024} },CPU |
        ConvertTo-PodeWebChartData -LabelProperty Name -DatasetProperty "内存使用",CPU
    }

    # 饼图
    New-PodeWebChart -Name 'Top Thread Count' -Type pie -AutoRefresh -AsCard -ScriptBlock{
      Get-Process |
        Select-Object  @{ Name="Name"; Expression={"$($_.ProcessName)($($_.Id))"} }, @{Name="线程数";Expression={$_.Threads.Count}} |
        Sort-Object -Property "线程数" -Descending |
        Select-Object -First 10 |
        ConvertTo-PodeWebChartData -LabelProperty Name -DatasetProperty "线程数"
    }

  )

  # Services 页面
  Add-PodeWebPage -Name "Services" -Icon "tools" -Layouts @(
    # 表格
    New-PodeWebTable -Name "Services" -AsCard -DataColumn Name -Filter -Paginate -PageSize 8 -ScriptBlock{
      $filter = $WebEvent.Data.Filter
      $filter = $filter -eq $null ? "" : $filter.Trim()
      $pageIndex = [int]$WebEvent.Data.PageIndex
      $pageSize = [int]$WebEvent.Data.PageSize
      $pageIndex = $pageIndex -lt 1 ? 1 : $pageIndex
      $skip = ($pageIndex-1)*$pageSize

      Write-Host "[Services] pageIndex=$pageIndex pageSize=$pageSize skip=$skip"

      #$data = foreach($s in (Get-Service | Where-Object {$_.Name.Contains($filter)} | Sort-Object Name -Descending | Select-Object -Skip $skip -First $pageSize))
      $data = foreach($s in (Get-Service | Select-Object -Skip $skip -First $pageSize))
      {
        $cannotStop = $s.CanStop ? $false : $true
        [ordered]@{
          Name = $s.Name
          DisplayName =  $s.DisplayName
          ServiceType = $s.ServiceType.ToString()
          StartType = $s.StartType.ToString()
          Status =$s.Status.ToString()
          Actions   = @(
            New-PodeWebButton -Name 'Stop' -Icon 'Stop-Circle' -Size Small -Colour Red -Disabled:$cannotStop  -ScriptBlock {
              #Stop-Service -Name $WebEvent.Data.Value -Force | Out-Null
              Show-PodeWebToast -Message "$($WebEvent.Data.Value) stopped"
              Sync-PodeWebTable -Id $ElementData.Parent.ID
            }
            New-PodeWebButton -Name 'Start' -Icon 'Play-Circle' -Size Small -Colour Green -ScriptBlock {
              # Start-Service -Name $WebEvent.Data.Value -Force | Out-Null
              Show-PodeWebToast -Message "$($WebEvent.Data.Value) started"
              Sync-PodeWebTable -Id $ElementData.Parent.ID
            }
          )
        }
      }

      $data | Update-PodeWebTable -Name 'Services' -PageIndex $pageIndex -TotalItemCount 1000
    } -Columns @(
      Initialize-PodeWebTableColumn -Key Actions -Alignment Center -Icon "gesture-tap-box"
    )
  )
}
