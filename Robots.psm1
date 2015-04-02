function Start-Robots
{
	######### Parameters ------------------------------------------------------------ 

	[CmdletBinding()]
	param
	(
		[int]$RobotsPerLevel = 5,
		[int]$TasersPerLevel = 5,
		[int]$LasersPerLevel = 2,
        [switch]$NoBanner,
        [switch]$NoScoreboard,
		[switch]$Quiet
	)

	######### Initialize -----------------------------------------------------------

    #region *** Declarations

    [string]$script:sVersion ="0.2"
	[int]$script:iWidth = $Host.UI.RawUI.WindowSize.Width - 1
	[int]$script:iHeight = $Host.UI.RawUI.WindowSize.Height
	[string]$WorkingDirectory = $PWD.Path
    [object]$script:oGameScope = @{
        Level = 0;
        Lives = 0;
        Score = 0;        
        HighScore = 0;
        TasersLeft = 0;
        LasersLeft = 0;
        LaserMode = $false;
        WaitTillEnd = $false;
    }
	
    ### This function is defined here so that we can create objects with sounds ###
	function Get-Sound([string]$Number)
	{	
		[string]$sSoundLocation = "{0}\sound_{1}.wav" -f $WorkingDirectory, $Number
		
		if (-not (Test-Path $sSoundLocation)) { Write-Warning ("Get-Sound:: Unable to locate sound: {0}" -f $sSoundLocation); Read-Host }
		
		return ($sSoundLocation)
	}

	<#
		(33..255) | % { "{0}:: {1}" -f $_, [char]$_ }

			ASCII   Character
			-----   ---------
			  164:: ¤
			  165:: ¥
			  167:: §
			  181:: µ
			  186:: º			  
			  197:: Å
			  199:: Ç
			  221:: Ý
			  230:: æ
			  231:: ç
			  240:: ð
			  242:: ò
			  243:: ó
			  246:: ö
	#>

	[object]$script:oCharacterTemplate = @{ 
		Color = "Yellow";
		Sprite = [char]220;
		AlternateSprite = [char]252;
		UseAltSprite = $false;
		DeadChar = "*";
		DeadColor = "Yellow";
		DeadSound = Get-Sound(10);
		Position = $null;
		IsActive = $true;
	}
	[object]$script:oRobotTemplate = @{ 
		NormalColor = "Red";
		Color = "Red";
		Sprite = [char]167;
		AlternateSprite = "s";
		UseAltSprite = $false;
		DeadChar = [char]230;
		DeadColor = "DarkRed";
		DeadSound = Get-Sound(3);
		DemobilizeCount = 0;
		DemobilizedColor = "Yellow";
		Position = $null;
        Lives = 1;
		IsActive = $true;
        Invisible = $false;
	}
	[object]$script:oTaserTemplate = @{ 
		Color = "Cyan";
		Sprite = "o";
		AlternateSprite = [char]186;
		UseAltSprite = $false;
		FlyCount = 0;
		Direction = "i";
		Position = $null;
		IsActive = $false;
	}
	[object]$script:oLaserTemplate = @{ 
		Color = "Cyan";
		Sprite = "+";
		AlternateSprite = "";
		UseAltSprite = $false;
		FlyCount = 0;
		Direction = "i";
		Position = $null;
		IsActive = $false;
	}

    [int]$script:iDefaultRobots = $RobotsPerLevel
	[bool]$script:bExitButtonHit = $false

	[int]$script:iDemobilizeFor = 10
	[int]$script:iMaxFlyCount = 20

	[object]$script:oRobots = New-Object System.Collections.Arraylist
	[object]$script:oSavedRobots = New-Object System.Collections.Arraylist
	[object]$script:oTasers = New-Object System.Collections.Arraylist

	[object]$script:oCharacter = $null
	[object]$script:oSavedCharacter = $null

	[array]$script:oMoveKeys = @("w", "e", "d", "c", "x", "z", "a", "q", "s")
	[array]$script:oShootKeys = @("i", "o", "l", ".", ",", "m", "j", "u", "k")

	[object]$script:oSound = New-Object Media.SoundPlayer
	[string]$script:sStartSong = Get-Sound(29)
	[string]$script:sStartSound = Get-Sound(2)
	[string]$script:sTaserSound = Get-Sound(10)
	[string]$script:sLaserSound = Get-Sound(24)
	[string]$script:sWarpSound = Get-Sound(8)
	[string]$script:sMoveSound = Get-Sound(27)
	[string]$script:sEmptySound = Get-Sound(101)
	[string]$script:sWinSound = Get-Sound(22)
	[string]$script:sLoseSound = Get-Sound(16)
	[string]$script:sYesSound = Get-Sound(24)
	[string]$script:sHitSound = Get-Sound(99)
	[string]$script:sExitSound = Get-Sound(20)
	
	[string]$sBanner = `
"RRRRR    OOOO   BBBBB    OOOO   TTTTTT  SSSS 
RR  RR  OO  OO  BB  BB  OO  OO    TT   SS  SS
RR  RR  OO  OO  BB  BB  OO  OO    TT   SS    
RRRRR   OO  OO  BBBBB   OO  OO    TT    SSSS 
RR RR   OO  OO  BB  BB  OO  OO    TT       SS
RR  RR  OO  OO  BB  BB  OO  OO    TT   SS  SS
RR  RR   OOOO   BBBBB    OOOO     TT    SSSS
      ___      __             __       __
     / _ \___ / /__  ___ ____/ /__ ___/ /
    / , _/ -_) / _ \/ _ ``/ _  / -_) _  / 
   /_/|_|\__/_/\___/\_,_/\_,_/\__/\_,_/ "

	[string]$sInstructions = "`
Objective:

 Destroy the aggressive robots before they destroy 
 you.  Out maneuver them so they crash into eachother.  
 Use your stun gun to immobilize them or your laser 
 to disintegrate them.  Good luck!
 

       Move Keys:       Shoot Keys:
      -----------       -----------
       (Q)(W)(E)         (U)(I)(O)
         \ | /             \ | /
      (A)- + -(D)       (J)- + -(L)
         / | \             / | \
       (Z)(S)(C)         (M)(K)(.)
          (X)               (,)
    
         - or -		Special Keys:
                        -------------
      (Arrow Keys)      (Spacebar) to warp
                        (Tab) to change guns
                        (End) to wait until end
                        (Esc) to exit"

    [string]$script:sScoreBoard = `
" _____________________/¯¯¯¯¯ Level {8,3:D4} ¯¯¯¯¯\____________________
/    Lives> {0,3:D3}    Laser Bullets({1})> {2,3:D3}        Score> {3,8:D8}   \
/    Robots> {4,3:D3}    Taser Charges({5})> {6,3:D3}    HighScore> {7,8:D8}    \";

    [int]$script:iScoreBoardHeight = ($script:sScoreBoard.Split([Environment]::NewLine).Length - 2)
    [int]$script:iHighScore = 0

	[int]$script:iReplayMove = 0
	[int]$script:iReplayWarp = 0
	[int]$script:iReplaySpeed = 75
	[bool]$script:bReplayMode = $false
	[object]$script:oReplayMoves = New-Object System.Collections.Arraylist
	[object]$script:oReplayWarps = New-Object System.Collections.Arraylist

    #endregion

	######### Functions ------------------------------------------------------------ 

    #region *** Character manipulation functions

	function Create-Character()
	{
		[object]$script:oCharacter = Generate-XY $script:oCharacterTemplate.Clone()
	}
		
	function Create-Robot([int]$RobotNumber)
	{
		$oRobot = Generate-XY $script:oRobotTemplate.Clone()
		$oRobot.UseAltSprite = (Get-Random -Minimum 1 -Maximum 10) -ge 5

        #Randomly create strong robots
        if ([int](Get-Random -Minimum 1 -Maximum 10) -le 3) 
        {
            $oRobot.Lives = 2
            $oRobot.NormalColor = "White"
            $oRobot.Color = "White"
        }

		[void]$script:oRobots.Add($oRobot)
	}
		
	function Create-Taser([int]$TaserNumber)
	{
		$oTaser = Generate-XY $script:oTaserTemplate.Clone()
		[void]$script:oTasers.Add($oTaser)
	}
	
	function Create-Bullet([object]$Direction)
	{
		[object]$Obj = $script:oLaserTemplate.Clone()
        $Obj.Position = New-Object Management.Automation.Host.Coordinates -ArgumentList $script:oCharacter.Position.X, $script:oCharacter.Position.Y
        #$Obj.Position = $script:oCharacter.Position
		$Obj.IsActive = $true

        if ($Direction.Character -eq $script:oShootKeys[0] -or $Direction.Character -eq $script:oShootKeys[4] -or $Direction.Character -eq $script:oShootKeys[8]) 
        {
            ### UP / DOWN
            $Obj.Sprite = "|"
		}
        else
        {  
            if ($Direction.Character -eq $script:oShootKeys[1] -or $Direction.Character -eq $script:oShootKeys[5]) 
            {
                ### UP-RIGHT / DOWN-LEFT
                $Obj.Sprite = "/"
            }
            else
            {
		        if ($Direction.Character -eq $script:oShootKeys[2] -or $Direction.Character -eq $script:oShootKeys[6]) 
                {
                    ### RIGHT / LEFT 
                    $Obj.Sprite = "-"
		        }
                else
                {
		            if ($Direction.Character -eq $script:oShootKeys[3] -or $Direction.Character -eq $script:oShootKeys[7]) 
                    {
                        ### DOWN-RIGHT / UP-LEFT 
                        $Obj.Sprite = "\"
        		    }
                } 
		    }
        }

        $Obj
	}
	
	function Generate-XY([object]$Obj)
	{
		[int]$iX = Get-Random -Minimum 1 -Maximum $script:iWidth
		[int]$iY = Get-Random -Minimum 1 -Maximum ($script:iHeight - $script:iScoreBoardHeight)
		$Obj.Position = New-Object Management.Automation.Host.Coordinates -ArgumentList $iX, $iY

		$Obj
	}

	function Move-Character()
	{
		<#
			while ($true) { $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }

			  	VirtualKeyCode   Character
			  	--------------   ---------
					  38 = Up Arrow
					  40 = Down Arrow
					  39 = Right Arrow
					  37 = Left Arrow

					  27 = Escape
		#>

		if ($script:bReplayMode)
		{
			$oKey = $script:oReplayMoves[$script:iReplayMove]
			$script:iReplayMove++

			Sleep -Milliseconds $script:iReplaySpeed
		}
		else
		{
            if (-not $script:oGameScope.WaitTillEnd)
            {
			    $host.UI.RawUI.FlushInputBuffer()
			    $oKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
			
			    ### Store keys for replay
			    [void]$script:oReplayMoves.Add($oKey)
            }
		}
		<# End Key #> if ($oKey.VirtualKeyCode -eq 35) { $script:oGameScope.WaitTillEnd = $true }
		<# Esc Key #> if ($oKey.VirtualKeyCode -eq 27) { $script:bExitButtonHit = $true }

        $oldX = $script:oCharacter.Position.x
        $oldY = $script:oCharacter.Position.y

		[string]$sSound = ""	
        <# IS CHANGE GUNS KEY #> if ($oKey.VirtualKeyCode -eq 9)
        {
            $script:oGameScope.LaserMode = -not $script:oGameScope.LaserMode
            Display-Scoreboard
        } 
        <# WARP OR SHOOT OR MOVE #> else 
        {
		    <# IS WARP KEY #> if ($oKey.Character -eq ' ') 
		    { 
			    <# DO REPLAY WARP #>if ($script:bReplayMode)
			    {
				    $script:oCharacter.Position.X = ($script:oReplayWarps[$script:iReplayWarp]).X
				    $script:oCharacter.Position.Y = ($script:oReplayWarps[$script:iReplayWarp]).Y
				    $script:iReplayWarp++
			    }
			    <# DO RANDOMIZE POSITION #> else
			    {
				    $script:oCharacter = Generate-XY $script:oCharacter
				
				    ### Store warped position for replay				
				    [void]$script:oReplayWarps.Add(@{ X=$script:oCharacter.Position.X; Y=$script:oCharacter.Position.Y })
			    }
			    $sSound = $script:sWarpSound
		    }
		    <# IS SHOOT OR MOVE #> else 
		    {
			    <# IS SHOOT KEY #> if ($script:oShootKeys -contains $oKey.Character)
			    {
                    <# DO SHOOT LASER #> if ($script:oGameScope.LaserMode)
                    {
				        <# SHOOT IF BULLETS LEFT #> if ($script:oGameScope.LasersLeft -gt 0 -and (Shoot-Laser -Direction $oKey.Character))
				        {				
					        $sSound = $script:sLaserSound
				        }
				        <# PLAY EMPTY SOUND #> else
				        {
					        $sSound = $script:sEmptySound
				        }
                    }
                    <# DO SHOOT TASER #> else 
                    {
				        <# SHOOT IF TASERS LEFT #> if ($script:oGameScope.TasersLeft -and (Launch-Taser -Direction $oKey.Character))
				        {				
					        $sSound = $script:sTaserSound
				        }
				        <# PLAY EMPTY SOUND #> else
				        {
					        $sSound = $script:sEmptySound
				        }
                    }
			    }
			    <# DEFAULT TO MOVE #> else 
			    {
				    $script:oCharacter = Move-InDirection -Obj $script:oCharacter -Keys $script:oMoveKeys -Direction $oKey
				    $sSound = $script:sMoveSound
			    }
		    }
        }

		if ($sSound.Length -gt 0) { Play-Sound $sSound }

        if ($script:oCharacter.Postion.X -ne $oldX -or $script:oCharacter.Position.Y -ne $oldY)
        {
            Set-ConsolePosition -X:$oldX -Y:$oldY
            Write-Host " " -NoNewLine		
        }

        Draw-Sprite $script:oCharacter
	}

	function Check-Character()
	{
		ForEach( $iRobot in (1..($RobotsPerLevel * $script:oGameScope.Level)) ) { Check-Robot -RobotNumber $iRobot -vsCharacter }
	}

    function Shoot-Laser([string]$Direction)
    {
        $script:oGameScope.LasersLeft--;
        Display-Scoreboard

        [object]$oBullet = Create-Bullet -Direction:@{ Character = $Direction }
        [object]$oPath = New-Object System.Collections.Arraylist
        
        while ($oBullet.IsActive)
        {
            $oBullet = Move-InDirection -Obj:$oBullet -Keys:$script:oShootKeys -Direction:@{ Character = $Direction } -DeactivateAtBorder
            $oPath.Add(@{ X = $oBullet.Position.X; Y = $oBullet.Position.Y })
            Draw-Sprite -Obj $oBullet
        }

        ForEach($oPoint in $oPath) 
        { 
            ForEach( $iRobot in (1..($RobotsPerLevel * $script:oGameScope.Level)) )
            {
                #Check-Robot -RobotNumber $iRobot 

                [string]$sClear = " "
                [string]$oColor = [System.ConsoleColor]::White
                if ($script:oRobots[$iRobot - 1].Position.X -eq $oPoint.X -and $script:oRobots[$iRobot - 1].Position.Y -eq $oPoint.Y)
                {
                    if ($script:oRobots[$iRobot - 1].Lives -eq 2)
                    {
                        $script:oRobots[$iRobot - 1].Lives = 1
                        $script:oRobots[$iRobot - 1].Color = $script:oRobotTemplate.Color
                        $script:oRobots[$iRobot - 1].NormalColor = $script:oRobotTemplate.NormalColor

                        $sClear = $script:oRobots[$iRobts - 1].Sprite
                        $oColor = $script:oRobotTemplate.Color
                    }
                    else
                    {
                        $script:oRobots[$iRobot - 1].Invisible = $true
                        $script:oRobots[$iRobot - 1].IsActive = $false
                        $script:oRobots[$iRobot - 1].Sprite = " "
					    Play-Sound $script:oRobots[$iRobot - 1].DeadSound

                        ### Hack to prevent collision with invisible objects
                        $script:oRobots[$iRobot - 1].Position.X = $script:iWidth - 1
                        $script:oRobots[$iRobot - 1].Position.Y = $script:iHeight - 1

                        $script:oGameScope.Score++;
                        $script:oGameScope.Robots--;
                        Display-Scoreboard
                    }
                }
            }

            Set-ConsolePosition -X:$oPoint.X -Y:$oPoint.Y
            Write-Host $sClear -NoNewline -ForegroundColor $oColor
        }
    }
	
	function Launch-Taser([string]$Direction)
	{
		### find an open slot
		[int]$iAvailableTaser = -1
		ForEach( $iTaser in (1..($TasersPerLevel * $script:oGameScope.Level)) ) { if (-not $script:oTasers[$iTaser - 1].IsActive) { $iAvailableTaser = $iTaser; break } }

		### activate it and return true
		if ($iAvailableTaser -gt 0) 
		{ 
			$script:oTasers[$iAvailableTaser - 1].IsActive = $true
			$script:oTasers[$iAvailableTaser - 1].Position.X = $script:oCharacter.Position.X
			$script:oTasers[$iAvailableTaser - 1].Position.Y = $script:oCharacter.Position.Y
			$script:oTasers[$iAvailableTaser - 1].Direction = $Direction
			$script:oTasers[$iAvailableTaser - 1].FlyCount = 0
			$script:oTasers[$iAvailableTaser - 1] = Move-InDirection `
				-Obj:$script:oTasers[$iAvailableTaser - 1] `
				-Keys $script:oShootKeys `
				-Direction:@{ Character = $Direction }

			Check-Tasers
			
			### Note: We dont play a sound here since we have a single threaded player ;)

            $script:oGameScope.TasersLeft--;
            Display-Scoreboard

			return ($true)
		}
		
		### otherwise return false
		return ($false) # meaning no Tasers are available
	}

	function Move-Tasers()
	{
		ForEach( $iTaser in (1..($TasersPerLevel * $script:oGameScope.Level)) ) { Move-Taser -TaserNumber $iTaser }
		
		Check-Tasers
	}

	function Move-Taser([int]$TaserNumber)
	{
		if ($script:oTasers[$TaserNumber - 1].IsActive)
		{
			Draw-Sprite $script:oTasers[$TaserNumber - 1] -Erase

			$script:oTasers[$TaserNumber - 1].FlyCount++
			if ($script:oTasers[$TaserNumber - 1].FlyCount -ge $script:iMaxFlyCount)
			{
				$script:oTasers[$TaserNumber - 1].IsActive = $false
			}
			else
			{
				$script:oTasers[$TaserNumber - 1] = Move-InDirection `
					-Obj:$script:oTasers[$TaserNumber - 1] `
					-Keys $script:oShootKeys `
					-Direction:@{ Character = $script:oTasers[$TaserNumber - 1].Direction }

				Draw-Sprite $script:oTasers[$TaserNumber - 1]
			}
		}
	}
	
	function Check-Tasers()
	{
		ForEach( $iTaser in (1..($TasersPerLevel * $script:oGameScope.Level)) ) { Check-Taser -TaserNumber $iTaser }
	}

	function Check-Taser([int]$TaserNumber)
	{
		$oTaser = $script:oTasers[($TaserNumber - 1)]
		if (-not $oTaser.IsActive) { return }

		ForEach( $iRobot in (1..($RobotsPerLevel * $script:oGameScope.Level)) ) 
		{
			if (-not $script:oRobots[$iRobot - 1].IsActive -or $script:oRobots[$iRobot - 1].Invisible) { continue }

			$bCollision = ($script:oRobots[$iRobot - 1].Position.X -eq $oTaser.Position.X `
				-and	   $script:oRobots[$iRobot - 1].Position.Y -eq $oTaser.Position.Y)

			if ($bCollision)
			{
				$script:oRobots[$iRobot - 1].DemobilizeCount = $script:iDemobilizeFor
				$script:oRobots[$iRobot - 1].Color = $script:oRobots[$iRobot - 1].DemobilizedColor
				
				$script:oTasers[($TaserNumber - 1)].IsActive = $false

				Play-Sound $script:sHitSound					
			}
		}
	}

	function Move-InDirection([object]$Obj, [object]$Direction, [object]$Keys, [switch]$DeactivateAtBorder)
	{
		### Move object based on Direction
		### Note: Directions are numbered in a clock-wise manner where up is 0, and 8 is in the center (or "down")

		<# UP #> if ($Direction.Character -eq $Keys[0] -or $Direction.VirtualKeyCode -eq 38) { 
			if ($Obj.Position.Y - 1 -ge 0) { $Obj.Position.Y = $Obj.Position.Y - 1 } else { if ($DeactivateAtBorder) { $Obj.IsActive = $false } }
            return $Obj
		}
		<# UP-RIGHT #> if ($Direction.Character -eq $Keys[1]) { 
			if ($Obj.Position.Y - 1 -ge 0) { $Obj.Position.Y-- } else { if ($DeactivateAtBorder) { $Obj.IsActive = $false } }
			if ($Obj.Position.X + 1 -lt $script:iWidth) { $Obj.Position.X = $Obj.Position.X + 1 } else { if ($DeactivateAtBorder) { $Obj.IsActive = $false } }
            return $Obj
		}
		<# RIGHT #> if ($Direction.Character -eq $Keys[2] -or $Direction.VirtualKeyCode -eq 39) { 
			if ($Obj.Position.X + 1 -lt $script:iWidth) { $Obj.Position.X = $Obj.Position.X + 1 } else { if ($DeactivateAtBorder) { $Obj.IsActive = $false } }
            return $Obj
		}
		<# DOWN-RIGHT #> if ($Direction.Character -eq $Keys[3]) { 
			if ($Obj.Position.Y + 1 -lt ($script:iHeight - $script:iScoreBoardHeight)) { $Obj.Position.Y = $Obj.Position.Y + 1 } else { if ($DeactivateAtBorder) { $Obj.IsActive = $false } }
			if ($Obj.Position.X + 1 -lt $script:iWidth) { $Obj.Position.X = $Obj.Position.X + 1 } else { if ($DeactivateAtBorder) { $Obj.IsActive = $false } }
            return $Obj
		}
		<# DOWN #> if ($Direction.Character -eq $Keys[4] -or $Direction.VirtualKeyCode -eq 40 -or $Direction.Character -eq $Keys[8]) { 
			if ($Obj.Position.Y + 1 -lt ($script:iHeight - $script:iScoreBoardHeight)) { $Obj.Position.Y = $Obj.Position.Y + 1 } else { if ($DeactivateAtBorder) { $Obj.IsActive = $false } }
            return $Obj
		}
		<# DOWN-LEFT #> if ($Direction.Character -eq $Keys[5]) { 
			if ($Obj.Position.Y + 1 -lt ($script:iHeight - $script:iScoreBoardHeight)) { $Obj.Position.Y = $Obj.Position.Y + 1 } else { if ($DeactivateAtBorder) { $Obj.IsActive = $false } }
			if ($Obj.Position.X - 1 -ge 0) { $Obj.Position.X = $Obj.Position.X - 1 } else { if ($DeactivateAtBorder) { $Obj.IsActive = $false } }
            return $Obj
		}
		<# LEFT #> if ($Direction.Character -eq $Keys[6] -or $Direction.VirtualKeyCode -eq 37) { 
			if ($Obj.Position.X - 1 -ge 0) { $Obj.Position.X = $Obj.Position.X - 1 } else { if ($DeactivateAtBorder) { $Obj.IsActive = $false } }
            return $Obj
		}
		<# UP-LEFT #> if ($Direction.Character -eq $Keys[7]) { 
			if ($Obj.Position.Y - 1 -ge 0) { $Obj.Position.Y = $Obj.Position.Y - 1 } else { if ($DeactivateAtBorder) { $Obj.IsActive = $false } }
			if ($Obj.Position.X - 1 -ge 0) { $Obj.Position.X = $Obj.Position.X - 1 } else { if ($DeactivateAtBorder) { $Obj.IsActive = $false } }
            return $Obj
		}

        return $Obj
	}

	function Move-Robots()
	{
		ForEach( $iRobot in (1..($RobotsPerLevel * $script:oGameScope.Level)) ) { Move-Robot -RobotNumber $iRobot }
		
		ForEach( $iRobot in (1..($RobotsPerLevel * $script:oGameScope.Level)) ) { Check-Robot -RobotNumber $iRobot }
	}

	function Move-Robot([int]$RobotNumber)
	{
		if ($script:oRobots[$RobotNumber - 1].IsActive)
		{
			Draw-Sprite $script:oRobots[$RobotNumber - 1] -Erase

			if ($script:oRobots[$RobotNumber - 1].DemobilizeCount -gt 0)
			{ 
				$script:oRobots[$RobotNumber - 1].DemobilizeCount-- 
				if ($script:oRobots[$RobotNumber - 1].DemobilizeCount -eq 0)
				{
					$script:oRobots[$RobotNumber - 1].Color = $script:oRobots[$RobotNumber - 1].NormalColor
				}
			}
			else
			{
				if ($script:oCharacter.Position.X -gt $script:oRobots[$RobotNumber - 1].Position.X)
				{
					$script:oRobots[$RobotNumber - 1].Position.X++
				}

				if ($script:oCharacter.Position.Y -gt $script:oRobots[$RobotNumber - 1].Position.Y)
				{
					$script:oRobots[$RobotNumber - 1].Position.Y++
				}

				if ($script:oCharacter.Position.X -lt $script:oRobots[$RobotNumber - 1].Position.X)
				{
					$script:oRobots[$RobotNumber - 1].Position.X--
				}

				if ($script:oCharacter.Position.Y -lt $script:oRobots[$RobotNumber - 1].Position.Y)
				{
					$script:oRobots[$RobotNumber - 1].Position.Y--
				}
			}
			
			Draw-Sprite $script:oRobots[$RobotNumber - 1]
		}
	}

	function Check-Robot([int]$RobotNumber, [switch]$vsCharacter)
	{	
		$oRobot = $script:oRobots[($RobotNumber - 1)]

		if ($vsCharacter)
		{
			$bCollision = ($script:oCharacter.Position.X -eq $oRobot.Position.X `
				-and	   $script:oCharacter.Position.Y -eq $oRobot.Position.Y)

			if ($bCollision)
			{
				$script:oCharacter.IsActive = $false
				$script:oCharacter.Sprite = $script:oCharacter.DeadChar
				$script:oCharacter.Color = $script:oCharacter.DeadColor

				Play-Sound $script:oCharacter.DeadSound

                $script:oGameScope.Lives--;
                Display-Scoreboard
			}
		}
		else
		{
			if (-not $oRobot.IsActive -or $oRobot.Invisible) { return }
			
			ForEach( $iRobot in (1..($RobotsPerLevel * $script:oGameScope.Level)) ) 
			{
				if ($iRobot -ne $RobotNumber -and -not $script:oRobots[$iRobot - 1].Invisible)
				{
					$bCollision = ($script:oRobots[$iRobot - 1].Position.X -eq $oRobot.Position.X `
						-and	   $script:oRobots[$iRobot - 1].Position.Y -eq $oRobot.Position.Y)

					if ($bCollision)
					{
                        if ($script:oRobots[$iRobot - 1].Lives -eq 2)
                        {
                            $script:oRobots[$iRobot - 1].Lives = 1
                            $script:oRobots[$iRobot - 1].Color = $script:oRobotTemplate.Color
                            $script:oRobots[$iRobot - 1].NormalColor = $script:oRobotTemplate.NormalColor
                        }
                        else
                        {
						    $script:oRobots[$iRobot - 1].IsActive = $false
						    $script:oRobots[$iRobot - 1].Sprite = $script:oRobots[$iRobot - 1].DeadChar
						    $script:oRobots[$iRobot - 1].Color = $script:oRobots[$iRobot - 1].DeadColor

						    $script:oRobots[$RobotNumber - 1].IsActive = $false
						    $script:oRobots[$RobotNumber - 1].Sprite = $script:oRobots[$RobotNumber - 1].DeadChar
						    $script:oRobots[$RobotNumber - 1].Color = $script:oRobots[$iRobot - 1].DeadColor

						    Play-Sound $script:oRobots[$RobotNumber - 1].DeadSound

                            $script:oGameScope.Score++;
                            $script:oGameScope.Robots--;
                            Display-Scoreboard
                        }
					}
				}
			}
		}

	}

    #endregion
	
    #region *** Screen functions

	function Draw-All()
	{
		ForEach( $iRobot in (1..($RobotsPerLevel * $script:oGameScope.Level)) ) 
		{
			Draw-Sprite $script:oRobots[$iRobot - 1]
		}
		Draw-Sprite $script:oCharacter
	}
	
	function Draw-Sprite([object]$Obj, [switch]$Erase)
	{
		Set-ConsolePosition $Obj.Position.X $Obj.Position.Y
		if (-not $Erase)
		{
			[string]$sSprite = $Obj.Sprite
			if ($Obj.IsActive -and $Obj.AlternateSprite.Length -gt 0)
			{
				if ($Obj.UseAltSprite) { $sSprite = $Obj.AlternateSprite }
				$Obj.UseAltSprite = -not $Obj.UseAltSprite
			}
			
			Write-Host $sSprite -NoNewLine -ForegroundColor $Obj.Color
		}
		else
		{			
			Write-Host " " -NoNewLine
		}
	}

	function Draw-Box([int]$X, [int]$Y, [int]$Width, [int]$Height)
	{
		Set-ConsolePosition $X $Y
		Write-Host (([char]164).ToString() * ($Width + 2)) 
	
		(1..$($Height)) | % { 
			
			Set-ConsolePosition $X ($Y + $_)
			Write-Host ("{0}{1}{2}" -f [char]164, (" ".ToString() * $Width), [char]164)
		}

		Set-ConsolePosition $X ($Y + $Height + 1)
		Write-Host (([char]164).ToString() * ($Width + 2)) 

		Set-ConsolePosition ($X+1) ($Y+1)
	}
	
	function Display-Message([string]$Message, [string]$Color, [int]$X = -1, [int]$Y = -1, [switch]$NoBox, [switch]$NoNewLine)
	{
		if ($X -eq -1) { $X = ($script:iWidth / 2) - ($Message.Length / 2) }
		if ($Y -eq -1) { $Y = ($script:iHeight / 2) - ($Message.Split([Environment]::NewLine).Length / 2) }

        if (-not $NoBox)
        {		
    		Draw-Box $X $Y $Message.Length $Message.Split([Environment]::NewLine).Length
        }
        else
        {
    		Set-ConsolePosition $X $(if ($Y -eq 999) { [Console]::CursorTop } else { $Y })
        }

        if (-not $NoNewLine)
        {
    		Write-Host $Message -ForegroundColor $Color
        } 
        else 
        {
    		Write-Host $Message -ForegroundColor $Color -NoNewline
        }
	}

    function Display-Scoreboard()
    {
        if ($NoScoreboard) { return }

        [string]$sScoreBoard = $script:sScoreBoard -f ( 
            $script:oGameScope.Lives, 
            $(if ($script:oGameScope.LaserMode) {"+"} else {" "}), # Laser indicator
            $script:oGameScope.LasersLeft, # Lasers left
            $script:oGameScope.Score,
            ($script:oRobots| Where IsActive -eq $true).Count,
            $(if (-not $script:oGameScope.LaserMode) {"o"} else {" "}), # Taser indicator
            $script:oGameScope.TasersLeft, # Tasers left
            $script:iHighScore,
            $script:oGameScope.Level
        )

		[int]$iIndex = 0
		ForEach($sLine in ($sScoreBoard -Split [Environment]::NewLine))
		{
			Display-Message -Message $sLine -Color Green -NoBox -X (-1) -Y ($script:iHeight - 3 + $iIndex) -NoNewLine
			$iIndex++
		}

        <#
            Lives
            TaserLaser $true
            Laser Bullets
            Score
            Robots
            TaserLaser $false
            Taser Charges
            HighScore
        #>
    }
	
	function Set-ConsolePosition([int]$X, [int]$Y)
	{ 
		$Host.UI.RawUI.CursorPosition = New-Object Management.Automation.Host.Coordinates -ArgumentList $X, $Y
	}
	
	function Scroll-Text([string]$Text, [int]$Indent = 0, [string[]]$Colors = @( "Cyan" ))
	{
		[int]$iIndex = 0
		ForEach($sLine in ($Text -Split [Environment]::NewLine))
		{
			Sleep -Milliseconds 25

			Write-Host ("{0}{1}" -f (" " * $Indent), $sLine) -ForegroundColor $Colors[$iIndex]
			$iIndex++; if ($iIndex -ge $Colors.Length) { $iIndex = 0 }
		}
	}

    #endregion

    #region *** Music / Sound functions

	function Play-Sound([string]$sSound)
	{
		if (-not $Quiet)
		{
			$script:oSound.SoundLocation = $sSound
			$script:oSound.Play()
		}
	}
	
	function Start-BGSong()
	{
        if (-not $Quiet) 
        {
		    "" | Out-File ("{0}\.playsong" -f $WorkingDirectory)
		
		    $oDummy = Start-Job -ArgumentList $WorkingDirectory `
			    -ScriptBlock {
				    param([string]$WorkingDirectory)
				    [object]$oSongPlayer = New-Object System.Media.SoundPlayer
				    [int]$iSongNumber = Get-Random -Maximum 7 -Minimum 1
				    $oSongPlayer.SoundLocation = "{0}\song_wmpaud{1}.wav" -f $WorkingDirectory, $iSongNumber
				    $oSongPlayer.PlayLooping()
				    While (Test-Path ("{0}\.playsong" -f $WorkingDirectory)) { Sleep 1 }
				    $oSongPlayer.Stop()

			    }
        }
	}
	
	function Stop-BGSong()
	{
        if (-not $Quiet) 
        { 
            Remove-Item ("{0}\.playsong" -f $WorkingDirectory) -Force -EA SilentlyContinue | Out-Null
        }
	}

    #endregion

    #region *** Game Level functions

	function Save-All()
	{
		$script:oSavedRobots = New-Object System.Collections.Arraylist
		$i = 0
		ForEach( $iRobot in (1..($RobotsPerLevel * $script:oGameScope.Level)) ) 
		{
			$oRobot = Generate-XY $script:oRobotTemplate.Clone()
			$oRobot.Position.X = $script:oRobots[$i].Position.X
			$oRobot.Position.Y = $script:oRobots[$i].Position.Y
			[void]$script:oSavedRobots.Add($oRobot)
			$i++
		}
		$script:oSavedCharacter = Generate-XY $script:oCharacterTemplate.Clone()
		$script:oSavedCharacter.Position.X = $script:oCharacter.Position.X
		$script:oSavedCharacter.Position.Y = $script:oCharacter.Position.Y
	}
	
	function Restore-All()
	{
		$script:oTasers = New-Object System.Collections.Arraylist
		ForEach( $iTaser in (1..($TasersPerLevel * $script:oGameScope.Level)) ) { Create-Taser -TaserNumber $iTaser }
		
		$script:iReplayMove = 0
		$script:iReplayWarp = 0
		$script:iReplaySpeed = [Math]::Abs($script:iReplaySpeed - 20)
		$script:oRobots = New-Object System.Collections.Arraylist
		$i = 0
		ForEach( $iRobot in (1..($RobotsPerLevel * $script:oGameScope.Level)) ) 
		{
			$oRobot = Generate-XY $script:oRobotTemplate.Clone()
			$oRobot.Position.X = $script:oSavedRobots[$i].Position.X
			$oRobot.Position.Y = $script:oSavedRobots[$i].Position.Y
			[void]$script:oRobots.Add($oRobot)
			$i++
		}
		$script:oCharacter = Generate-XY $script:oCharacterTemplate.Clone()
		$script:oCharacter.Position.X = $script:oSavedCharacter.Position.X
		$script:oCharacter.Position.Y = $script:oSavedCharacter.Position.Y
	}

    function Reset-Game()
    {
        if ($script:oGameScope.Score -gt $script:iHighScore)
        {
            ###
            ###### Save Highscore
            ###

            $script:iHighScore = $script:oGameScope.Score
            $script:iHighScore | Out-File .highscore
        }
        else
        {
            ###
            ###### Load Highscore
            ###
    
            if (Test-Path .highscore) { $script:iHighScore = [int](Get-Content .highscore) }
        }

        ###
        ###### Reset all values
        ###

        $script:oGameScope.Level = 1
        $script:oGameScope.Robots = $RobotsPerLevel
        $script:oGameScope.TasersLeft = $TasersPerLevel
        $script:oGameScope.LasersLeft = $LasersPerLevel
        $script:oGameScope.Lives = 3
        $script:oGameScope.Score = 0
    }

	function Get-Response([string]$Prompt, [string[]]$Options, [string]$Default)
	{
		$host.UI.RawUI.FlushInputBuffer()

        Display-Message -Message "$Prompt $Default$([char]8)" -NoNewLine -NoBox -Color Green -X (-1) -Y (999)
		$oKey = $null
		while ($Options -notcontains $oKey.Character)
		{
   			$oKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
			if ($oKey.VirtualKeyCode -eq 13) { $oKey = @{ Character = $Default } }
			if ($oKey.VirtualKeyCode -eq 32) { $oKey = @{ Character = $Default } }
   			$sKey = $oKey.Character
		}

		return ($sKey)
	}

    #endregion

	######### Main ----------------------------------------------------------------- 

    function Main()
	{
		while ($true)
		{
            Reset-Game

            ###
            ###### Instruction/Intro Page
            ###

            if (-not $NoBanner)
            {
			    Play-Sound $script:sStartSong

			    ### Put a space in the lower left corner scroll everything off the screen
			    Scroll-Text ([Environment]::NewLine * $script:iHeight)

    			[int]$iBannerWidth = ($sBanner -Split [Environment]::NewLine | % { $_.Length } | Measure -Maximum).Maximum
                [int]$iIndent = (($script:iWidth / 2) - ($iBannerWidth / 2))
	    		Scroll-Text -Indent $iIndent -Colors "Red", "Red", "Cyan", "White", "Cyan" -Text $sBanner

			    [int]$iInstructionsWidth = ($sInstructions -Split [Environment]::NewLine | % { $_.Length } | Measure -Maximum).Maximum
                [int]$iIndent = (($script:iWidth / 2) - ($iInstructionsWidth / 2))
			    Scroll-Text -Indent $iIndent -Text $sInstructions
			    Scroll-Text ([Environment]::NewLine)
            }

			Write-Host ("- " * (($script:iWidth / 2) - 1)) -NoNewline -ForegroundColor DarkGreen
            $sKey = Get-Response -Prompt "Play with sound? (y/n/r/q):" -Options "y","n","r","q" -Default "y"
			if ($sKey -eq "q") { break }

			$script:bReplayMode = ($sKey -eq "r")
			$Quiet = -not ($sKey -eq "y")

			$script:oSound.Stop();

            ###
            ###### Game
            ###

			[bool]$bPlaying = $true
			while ($bPlaying)
			{
				$script:bExitButtonHit = $false
				Clear-Host

                Display-Message "   Level $($script:oGameScope.Level)  " -Color Red ### -X (Get-Random -Minimum 1 -Maximum ($script:iWidth - 10)) -Y (Get-Random -Minimum 1 -Maximum ($script:iHeight - 3))	
                Start-Sleep -Seconds 2
				Clear-Host
                
				Play-Sound $script:sStartSound

				if ($script:bReplayMode)
				{
					Restore-All
				}
				else
				{
					### Create Robots
					$script:oRobots = New-Object System.Collections.Arraylist
					ForEach( $iRobot in (1..($RobotsPerLevel * $script:oGameScope.Level)) ) { Create-Robot -RobotNumber $iRobot }

					### Create Tasers
					$script:oTasers = New-Object System.Collections.Arraylist
					ForEach( $iTaser in (1..($TasersPerLevel * $script:oGameScope.Level)) ) { Create-Taser -TaserNumber $iTaser }

					### Create Character
					Create-Character

					Save-All
				}

                Display-Scoreboard
				Draw-All

				Start-BGSong
	
                ###
                ###### Game Loop
                ###
				while ($script:oCharacter.IsActive -and ($script:oRobots | Where IsActive -eq $True).Count -gt 0 -and -not $script:bExitButtonHit)
				{
					Move-Character				
					Move-Tasers
					Move-Robots

					Check-Character
					
					Draw-All
				}

				Stop-BGSong
				Set-ConsolePosition -X 1 -Y 0

                $script:oGameScope.WaitTillEnd = $false
                $script:oGameScope.LasersLeft = $script:oGameScope.LasersLeft + ($LasersPerLevel * $script:oGameScope.Level)
                $script:oGameScope.TasersLeft = $script:oGameScope.TasersLeft + ($TasersPerLevel * $script:oGameScope.Level)

                <# Character died #> if (-not $script:oCharacter.IsActive)
				{
					Play-Sound $script:sLoseSound
					Sleep 3

                    if ($script:oGameScope.Lives -eq 0) { break }
				}
				else
				{
					<# User pressed Escape #> if ($script:bExitButtonHit)
					{
                        break
                    }

                    <# Level Cleared #>
					Display-Message " *** Level Cleared *** " -Color Green
					Play-Sound $script:sWinSound

                    $script:oGameScope.Level++

					Sleep 3
				}                

				#if (-not $script:bReplayMode) 
				#{
				#	$script:iReplayWarp = 0
				#	$script:iReplayMove = 0
				#	$script:bReplayMode = $false
				#	$script:oReplayMoves = New-Object System.Collections.Arraylist
				#	$script:oReplayWarps = New-Object System.Collections.Arraylist
				#}
			}

			Play-Sound $script:sExitSound

			Set-ConsolePosition 0 $script:iHeight
			(1..($script:iHeight)) | % { Sleep -Milliseconds 15; Write-Host }
		}
	}
	
	[console]::CursorVisible = $false
	[console]::Title = "Robots Reloaded ($($script:sVersion))"
	Main
	[console]::CursorVisible = $true

	######### End ------------------------------------------------------------ 
}

# SIG # Begin signature block
# MIIFuQYJKoZIhvcNAQcCoIIFqjCCBaYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUCJ/d3sPJZGQaVFYvb5GTlsEa
# STqgggNCMIIDPjCCAiqgAwIBAgIQO6RDgbW1RrBESN2cn9IPYDAJBgUrDgMCHQUA
# MCwxKjAoBgNVBAMTIVBvd2VyU2hlbGwgTG9jYWwgQ2VydGlmaWNhdGUgUm9vdDAe
# Fw0xMzA5MTAwMjI0MTlaFw0zOTEyMzEyMzU5NTlaMBoxGDAWBgNVBAMTD1Bvd2Vy
# U2hlbGwgVXNlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMdWWMLo
# kbcZQfR8K0amX6OH4gUbJIORhfLlHyw1NbksyAsa8fpv/e0yTsbbnRVh1PS1yVNQ
# PBUKcx0lV/NnCNTTe60f0pkPWgv5BfNPFUmuMwwIBLQULB2/cAA/JcJ+cdxSZtW0
# 47SrznlkdR7RMWKK7kZi2mk+OBa6GIdHgQe9OFuGcNbwtp6W+Ta495wPQ1weZ9qc
# 5dYJjXt+KwUzpMawaAlBz/iq4+prQWYiZERKJ9ETuBehTyXc2UzjApdAzdP52PQo
# 38yp7cpq7nLgwJaAJrOpeJEexqaNoR0lgoQiUztvNiFMGshAwRLrpX+bC1TnLoEK
# 8CiBx6DlmzUJhEkCAwEAAaN2MHQwEwYDVR0lBAwwCgYIKwYBBQUHAwMwXQYDVR0B
# BFYwVIAQ/WASk1WU5PagcmL93Xncm6EuMCwxKjAoBgNVBAMTIVBvd2VyU2hlbGwg
# TG9jYWwgQ2VydGlmaWNhdGUgUm9vdIIQGSM6AmVsV6BAO1NV7oW4ATAJBgUrDgMC
# HQUAA4IBAQARxQqg3wlRn06j88s74FKqtRIWLt4p/INdwNFcYIqYvxGDrDt6ZtOA
# 88UvCFCfyGBFvwbu20Yd1wucdQubtWD29RI+gHKH+PDlCynAFn9BNWRZipSgava+
# 3qaDUNXx8ezQU6BHmkH7HygYs3sqCqqcjI0Nn7rH2mVIYEdM8lOfraYirgpkRHPL
# K7AtDZDA1rNyezVG9py8IJPwe+dQLVDSHyqfPhkFH0wiDdmxs8f5gn1cTJ94pqtn
# HOCOqhEkZcTGCzpKJ+/txoRJNtJdOBa9eoEU386WJDuS0g3pJ3wtK/+Ibs2jNlMQ
# fTAnoX3ujkpxxGLbib5ywLVneMeFp2OfMYIB4TCCAd0CAQEwQDAsMSowKAYDVQQD
# EyFQb3dlclNoZWxsIExvY2FsIENlcnRpZmljYXRlIFJvb3QCEDukQ4G1tUawREjd
# nJ/SD2AwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFOuQcLpX5VVPZb08pw8tlxG1Lp9HMA0GCSqG
# SIb3DQEBAQUABIIBAILITqGney8q+Ixghvwjfc+WG1tUV1LU0Wx33hCtMQ3UTCyk
# SeNzYQBm+uiRIcWNnhja57NxqdKAmJcLePMC9HX3HbI+hJuCq63d+dPw4L7DttRC
# Cn0Mj3CJpeJsQx+4h3VTBUkJHKmcp6qr/JPFJTqtElTYuKRbN/5oFAb93rpY473v
# efGz3IMh6G5mRpy79yjPDOWnva4n6Soz2pi/D8IK9QfpErjEITbu9Nf6zzHOdtia
# Bfde5t17isjmCJ7Rr1RL0xj9gwo1NHm0owLc4320lpxKQK6UCAKxxHWg9QT3YtKc
# BeyPLDvprwBtd8meHh3m4ixLJxn/ammie0TMlLk=
# SIG # End signature block
