state("DARKSOULS")
{
}

state("DarkSoulsRemastered")
{
}

startup
{   
    /* USER CONFIGURABLE SECTION */

    refreshRate = 60;
    vars.NumCyclesPerShift = 30;

    /* END OF USER CONFIGURABLE SECTION */

    /* SPLIT LOGIC VARS */

    Action resetSplitLogicVars = (() =>
    {
        vars.NotLosingTime = true;
        vars.PrevSplitIndexWithComparison = (int)-1;
        vars.LatestSplitIndexWithComparisonSoFar = (int)-1;
    });

    resetSplitLogicVars();

    timer.OnStart += ((s, e) =>
    {
        resetSplitLogicVars();
    });

    /* HAIR VARS */

    vars.CurrentlyShiftingHairColor = false;
    vars.HairDeltas = new float[3];
    vars.CurrentHairColor = new float[3] {(float) 0.0, (float) 0.0, (float) 0.0}; // R, G, B
    vars.TargetHairColor = new System.Drawing.Color();
    vars.CurrentHairShiftCycle = 0;

    /* HAIR COLOR DELEGATES */

    vars.SetHairVars = (Action<System.Drawing.Color>) ((color) => 
    {
        vars.CurrentHairColor = new float[] {(float) color.R / 255, (float) color.G / 255, (float) color.B / 255};
    });

    vars.ColorToFloatArray = (Func<System.Drawing.Color, float[]>) ((color) =>
    {
        return new float[] {(float) color.R / 255, (float) color.G / 255, (float) color.B / 255};
    });

    vars.InitializeHairColorShift = (Action<System.Drawing.Color>) ((targetColor) =>
    {
        if (vars.TargetHairColor.Equals(targetColor))
        {
            // do nothing
        }
        else
        {
            vars.TargetHairColor = targetColor;
            vars.CurrentlyShiftingHairColor = true;
            vars.CurrentHairShiftCycle = 0;

            float[] targetColorArr = vars.ColorToFloatArray(targetColor);
            float[] currColorArr = vars.CurrentHairColor;

            for (int i = 0; i < 3; i++)
            {
                vars.HairDeltas[i] = (targetColorArr[i] - currColorArr[i]) / vars.NumCyclesPerShift;
            }
        }
    });

    vars.ShiftHairVars = (Action) (() => 
    {
        if (!vars.CurrentlyShiftingHairColor)
        {
            // do nothing
        }
        else if (vars.CurrentHairShiftCycle >= vars.NumCyclesPerShift - 1)
        {
            vars.SetHairVars(vars.TargetHairColor);
            vars.CurrentlyShiftingHairColor = false;
        }
        else
        {
            float[] hairDeltasArr = vars.HairDeltas;
            float[] currColorArr = vars.CurrentHairColor;

            for (int i = 0; i < 3; i++)
            {
                vars.CurrentHairColor[i] = currColorArr[i] + hairDeltasArr[i];
            }
        }

        vars.CurrentHairShiftCycle++;
    });
}

init
{
    /* MEMORY STUFF */

    vars.GetAOBRelativePointer = (Func<SignatureScanner, SigScanTarget, int, int, IntPtr>) ((scanner, sst, aobOffset, instructionLength) => 
    {
        IntPtr ptr = scanner.Scan(sst);
        int offset = memory.ReadValue<int>(ptr + aobOffset);
        return ptr + offset + instructionLength;
    });

    vars.GetLowestLevelPtr = (Func<DeepPointer, IntPtr>) ((deepPointer) => 
    {
        IntPtr tempPtr = (IntPtr) 0;

        deepPointer.DerefOffsets(game, out tempPtr);
        while(tempPtr == (IntPtr) 0)
        {
            Thread.Sleep(500);
            deepPointer.DerefOffsets(game, out tempPtr);
        }

        return tempPtr;
    });

    SignatureScanner sigScanner = new SignatureScanner(game, modules.First().BaseAddress, modules.First().ModuleMemorySize);

    if (game.ProcessName.ToString() == "DARKSOULS")
    {
        SigScanTarget playerAOB = new SigScanTarget(0, "A1 ?? ?? ?? ?? 8B 40 34 53 32");
        IntPtr playerPtr = (IntPtr) memory.ReadValue<int>(sigScanner.Scan(playerAOB) + 1);

        vars.RgbSkinColorDeepPtr = new DeepPointer(playerPtr, 0x8, 0x3D2);
        
        vars.RgbHairRedDeepPtr = new DeepPointer(playerPtr, 0x08, 0x380);
        vars.RgbHairGreenDeepPtr = new DeepPointer(playerPtr, 0x08, 0x384);
        vars.RgbHairBlueDeepPtr = new DeepPointer(playerPtr, 0x08, 0x388);
    }
    else if (game.ProcessName.ToString() == "DarkSoulsRemastered")
    {
        SigScanTarget playerAOB = new SigScanTarget(0, "48 8B 05 ?? ?? ?? ?? 45 33 ED 48 8B F1 48 85 C0");
        IntPtr playerPtr = vars.GetAOBRelativePointer(sigScanner, playerAOB, 3, 7);

        vars.RgbSkinColorDeepPtr = new DeepPointer(playerPtr, 0x10, 0x512);
        
        vars.RgbHairRedDeepPtr = new DeepPointer(playerPtr, 0x10, 0x4C0);
        vars.RgbHairGreenDeepPtr = new DeepPointer(playerPtr, 0x10, 0x4C4);
        vars.RgbHairBlueDeepPtr = new DeepPointer(playerPtr, 0x10, 0x4C8);
    }

    vars.RgbSkinColorPtr = vars.GetLowestLevelPtr(vars.RgbSkinColorDeepPtr);

    vars.RgbHairRedPtr = vars.GetLowestLevelPtr(vars.RgbHairRedDeepPtr);
    vars.RgbHairGreenPtr = vars.GetLowestLevelPtr(vars.RgbHairGreenDeepPtr);
    vars.RgbHairBluePtr = vars.GetLowestLevelPtr(vars.RgbHairBlueDeepPtr);

    vars.WriteHairVarsToMem = (Action) (() =>
    {
        float hairR = vars.CurrentHairColor[0];
        float hairG = vars.CurrentHairColor[1];
        float hairB = vars.CurrentHairColor[2];

        IntPtr hairRedPtr = vars.RgbHairRedPtr;
        game.WriteBytes(hairRedPtr, BitConverter.GetBytes(hairR));
       
        IntPtr hairGreenPtr = vars.RgbHairGreenPtr;
        game.WriteBytes(hairGreenPtr, BitConverter.GetBytes(hairG));
       
        IntPtr hairBluePtr = vars.RgbHairBluePtr;
        game.WriteBytes(hairBluePtr, BitConverter.GetBytes(hairB));
    });
}

/* isLoading is used so that the following code only runs when the timer is 
running. It never returns true, so it never affects the timer */
isLoading
{
    // PersonalBestColor
    // AheadGainingTimeColor
    // AheadLosingTimeColor
    // BehindGainingTimeColor
    // BehindLosingTimeColor
    // BestSegmentColor

    var currSplitIndex = timer.CurrentSplitIndex;
    var currComparison = timer.CurrentComparison;
    var currTimingMethod = timer.CurrentTimingMethod;

    if (vars.LatestSplitIndexWithComparisonSoFar < currSplitIndex)
    {
        vars.PrevSplitIndexWithComparison = vars.LatestSplitIndexWithComparisonSoFar;
    }

    Time currSplitComparisonTimeObject = timer.CurrentSplit.Comparisons[currComparison];

    /* If there is no comparison time for this split, LiveSplit considers you 
    ahead, even if you are behind a later split */
    if (currSplitComparisonTimeObject.Equals(default(Time)))
    {
        vars.InitializeHairColorShift(timer.LayoutSettings.AheadGainingTimeColor);
    }
    else
    {
        TimeSpan currSplitComparisonTime = (TimeSpan) currSplitComparisonTimeObject[currTimingMethod];
        TimeSpan currTime = (TimeSpan) timer.CurrentTime[currTimingMethod];

        if (vars.PrevSplitIndexWithComparison >= 0)
        {
            int prevSplitIndexWithComparison = vars.PrevSplitIndexWithComparison;

            TimeSpan prevSplitSplitTime = (TimeSpan) timer.Run[prevSplitIndexWithComparison].SplitTime[currTimingMethod];
            TimeSpan prevSplitComparisonTime = (TimeSpan) timer.Run[prevSplitIndexWithComparison].Comparisons[currComparison][currTimingMethod];
            vars.NotLosingTime = ( (currTime - currSplitComparisonTime) <= (prevSplitSplitTime - prevSplitComparisonTime) );
        }

        if (currTime <= currSplitComparisonTime)
        {
            if (vars.NotLosingTime || currSplitIndex == 0)
            {
                vars.InitializeHairColorShift(timer.LayoutSettings.AheadGainingTimeColor);
            }
            else
            {
                vars.InitializeHairColorShift(timer.LayoutSettings.AheadLosingTimeColor);
            }
        }
        else
        {
            if (vars.NotLosingTime && !(currSplitIndex == 0))
            {
                vars.InitializeHairColorShift(timer.LayoutSettings.BehindGainingTimeColor);
            }
            else
            {
                vars.InitializeHairColorShift(timer.LayoutSettings.BehindLosingTimeColor);
            }

        }

        // if current split has a comparison, save index of split for later
        vars.LatestSplitIndexWithComparisonSoFar = currSplitIndex;
    }

    vars.ShiftHairVars();
    vars.WriteHairVarsToMem();
}