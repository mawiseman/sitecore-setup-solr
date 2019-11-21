###############################################################################
# Simple Textbased Powershell Menu
# Author : Michael Albert
# E-Mail : info@michlstechblog.info
# License: none, feel free to modify
# usage:
# Source the menu.ps1 file in your script:
# . .\menu.ps1
# fShowMenu requieres 2 Parameters:
# Parameter 1: [string]menuTitle
# Parameter 2: [IDictionary]@{[string]"ReturnString1"=[string]"Menu Entry 1";[string]"ReturnString2"=[string]"Menu Entry 2";[string]"ReturnString3"=[string]"Menu Entry 3"
# Return     : Select String
# For example:
# ShowMenu "Choose your favorite Band - Un-ordered" @{"sl"="Slayer";"me"="Metallica";"ex"="Exodus";"an"="Anthrax"}
# ShowMenu "Choose your favorite Band - Ordered" ([ordered]@{"sl"="Slayer";"me"="Metallica";"ex"="Exodus";"an"="Anthrax"})
# #############################################################################

function ShowMenu() {
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[System.String]$menuTitle,
		[Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Ordered')]
		[System.Collections.IDictionary]$menuEntries
	)
	begin {
		# Orginal Konsolenfarben zwischenspeichern
		[System.Int16]$SavedBackgroundColor = [System.Console]::BackgroundColor
		[System.Int16]$SavedForegroundColor = [System.Console]::ForegroundColor
		
		# Menu Colors
		# inverse fore- and backgroundcolor 
		[System.Int16]$MenuForeGroundColor = $SavedForegroundColor
		[System.Int16]$MenuBackGroundColor = $SavedBackgroundColor
		[System.Int16]$MenuBackGroundColorSelectedLine = $MenuForeGroundColor
		[System.Int16]$MenuForeGroundColorSelectedLine = $MenuBackGroundColor
		
		# Alternative, colors
		#[System.Int16]$MenuBackGroundColor=0
		#[System.Int16]$MenuForeGroundColor=7
		#[System.Int16]$MenuBackGroundColorSelectedLine=10
		
		# Init
		[System.Int16]$MenuStartLineAbsolute = 0
		[System.Int16]$MenuLoopCount = 0
		[System.Int16]$MenuSelectLine = 1
		[System.Int16]$MenuEntriesTotal = $menuEntries.Count
		[Hashtable]$Menu = @{ };
		[Hashtable]$MenuHotKeyList = @{ };
		[Hashtable]$MenuHotKeyListReverse = @{ };
		[System.Int16]$MenuHotKeyChar = 0
		[System.String]$ValidChars = ""
	}
	process {
		[System.Console]::WriteLine(" " + $menuTitle)

		# Für die eindeutige Zuordnung Nummer -> Key
		$MenuLoopCount = 1
		
		# Start Hotkeys mit "1"!
		$MenuHotKeyChar = 49

		foreach ($sKey in $menuEntries.Keys) {
			$Menu.Add([System.Int16]$MenuLoopCount, [System.String]$sKey)
			# Hotkey zuordnung zum Menueintrag
			$MenuHotKeyList.Add([System.Int16]$MenuLoopCount, [System.Convert]::ToChar($MenuHotKeyChar))
			$MenuHotKeyListReverse.Add([System.Convert]::ToChar($MenuHotKeyChar), [System.Int16]$MenuLoopCount)
			$ValidChars += [System.Convert]::ToChar($MenuHotKeyChar)
			$MenuLoopCount++
			$MenuHotKeyChar++
			
			# Weiter mit Kleinbuchstaben
			if ($MenuHotKeyChar -eq 58) { $MenuHotKeyChar = 97 }
			# Weiter mit Großbuchstaben
			elseif ($MenuHotKeyChar -eq 123) { $MenuHotKeyChar = 65 }
			# Jetzt aber ende
			elseif ($MenuHotKeyChar -eq 91) {
				Write-Error " Menu too big!"
				exit(99)
			}
		}
		
		# Remember Menu start
		[System.Int16]$BufferFullOffset = 0
		$MenuStartLineAbsolute = [System.Console]::CursorTop
		do {
			####### Draw Menu  #######
			[System.Console]::CursorTop = ($MenuStartLineAbsolute - $BufferFullOffset)
			for ($MenuLoopCount = 1; $MenuLoopCount -le $MenuEntriesTotal; $MenuLoopCount++) {
				[System.Console]::Write("`r")
				[System.String]$PreMenuline = ""
				$PreMenuline = "  " + $MenuHotKeyList[[System.Int16]$MenuLoopCount]
				$PreMenuline += ": "
				if ($MenuLoopCount -eq $MenuSelectLine) {
					[System.Console]::BackgroundColor = $MenuBackGroundColorSelectedLine
					[System.Console]::ForegroundColor = $MenuForeGroundColorSelectedLine
				}
				if ($menuEntries.Item([System.String]$Menu.Item($MenuLoopCount)).Length -gt 0) {
					[System.Console]::Write($PreMenuline + $menuEntries.Item([System.String]$Menu.Item($MenuLoopCount)))
				}
				else {
					[System.Console]::Write($PreMenuline + $Menu.Item($MenuLoopCount))
				}
				[System.Console]::BackgroundColor = $MenuBackGroundColor
				[System.Console]::ForegroundColor = $MenuForeGroundColor
				[System.Console]::WriteLine("")
			}
			[System.Console]::BackgroundColor = $MenuBackGroundColor
			[System.Console]::ForegroundColor = $MenuForeGroundColor
			
			[System.Console]::Write("  Your choice: " )
			if (($MenuStartLineAbsolute + $MenuLoopCount) -gt [System.Console]::BufferHeight) {
				$BufferFullOffset = ($MenuStartLineAbsolute + $MenuLoopCount) - [System.Console]::BufferHeight
			}
			####### End Menu #######

			####### Read Kex from Console 
			$InputChar = [System.Console]::ReadKey($true)
			
			# Down Arrow?
			if ([System.Int16]$InputChar.Key -eq [System.ConsoleKey]::DownArrow) {
				if ($MenuSelectLine -lt $MenuEntriesTotal) {
					$MenuSelectLine++
				}
			}
			
			# Up Arrow
			elseif ([System.Int16]$InputChar.Key -eq [System.ConsoleKey]::UpArrow) {
				if ($MenuSelectLine -gt 1) {
					$MenuSelectLine--
				}
			}
			elseif ([System.Char]::IsLetterOrDigit($InputChar.KeyChar)) {
				[System.Console]::Write($InputChar.KeyChar.ToString())	
			}

			[System.Console]::BackgroundColor = $MenuBackGroundColor
			[System.Console]::ForegroundColor = $MenuForeGroundColor
		} while (([System.Int16]$InputChar.Key -ne [System.ConsoleKey]::Enter) -and ($ValidChars.IndexOf($InputChar.KeyChar) -eq -1))

		# reset colors
		[System.Console]::ForegroundColor = $SavedForegroundColor
		[System.Console]::BackgroundColor = $SavedBackgroundColor

		if ($InputChar.Key -eq [System.ConsoleKey]::Enter) {
			[System.Console]::Writeline($MenuHotKeyList[$MenuSelectLine])
			return([System.String]$Menu.Item($MenuSelectLine))
		}
		else {
			[System.Console]::Writeline("")
			return($Menu[$MenuHotKeyListReverse[$InputChar.KeyChar]])
		}
	}	
}

function TestMenu() {
	ShowMenu -menuTitle "Hashtable Options" -menuEntries @{"one" = "one"; "two" = "two"; "three" = "three"}

	ShowMenu -menuTitle "Ordered Hashtable Options" -menuEntries ([ordered]@{"one" = "one"; "two" = "two"; "three" = "three"})
}

Export-ModuleMember ShowMenu, TestMenu