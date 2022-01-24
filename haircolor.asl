state("DARKSOULS")
{
}

state("DarkSoulsRemastered")
{
}

startup
{    
    /* USER CONFIGURABLE SECTION */

    // positive integer
    // reduce to reduce CPU usage, if necessary
    refreshRate = 60;
    
    // positive integer
    // higher --> slower hair color changes; lower --> faster; 1 --> instantaneous
    vars.NumIterationsPerShift = 30;

    /* END OF USER CONFIGURABLE SECTION */

    /* TIMER VARS */

    vars.OldTimerColor = new System.Drawing.Color();

    /* HAIR VARS */

    vars.CurrentlyShiftingHairColor = false;
    vars.HairDeltas = new float[3];
    vars.CurrentHairColor = new float[3];
    vars.ShiftStartHairColor = new float[3];
    vars.TargetHairColor = new System.Drawing.Color();
    vars.HairShiftIterationNum = 0;

    /* UTIL FUNC */

    vars.ColorToFloatArray = (Func<System.Drawing.Color, float[]>) ((color) =>
    {
        return new float[] {(float) color.R / 255, (float) color.G / 255, (float) color.B / 255};
    });

    /* HAIR COLOR ACTIONS (AFFECT HAIR COLOR STATE) */

    vars.SetHairVars = (Action<System.Drawing.Color>) ((color) => 
    {
        vars.CurrentHairColor = new float[] {(float) color.R / 255, (float) color.G / 255, (float) color.B / 255};
    });

    vars.InitializeHairColorShift = (Action<System.Drawing.Color>) ((targetColor) =>
    {
        if (!vars.TargetHairColor.Equals(targetColor))
        {
            vars.CurrentHairColor = vars.GetHairColorFromMemory();
            vars.ShiftStartHairColor = vars.CurrentHairColor;

            vars.TargetHairColor = targetColor;
            vars.CurrentlyShiftingHairColor = true;
            vars.CurrentHairShiftCycle = 0;

            float[] targetColorArr = vars.ColorToFloatArray(targetColor);
            float[] currColorArr = vars.CurrentHairColor;

            for (int i = 0; i < 3; i++)
            {
                vars.HairDeltas[i] = (targetColorArr[i] - currColorArr[i]) / vars.NumIterationsPerShift;
            }
        }
    });

    vars.ShiftHairVars = (Action) (() => 
    {
        if (vars.CurrentlyShiftingHairColor)
        {
            if (vars.CurrentHairShiftCycle >= vars.NumIterationsPerShift - 1)
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
        }
        
        vars.CurrentHairShiftCycle++;
    });

    /* TIMER / SPLIT FUNCS */

    vars.GetCurrentTimerColor = (Func<int, System.Drawing.Color>) ((prevDeltaIndex) =>
    {
        var currSplitIndex = timer.CurrentSplitIndex;
        var comparison = timer.CurrentComparison;
        var timingMethod = timer.CurrentTimingMethod;

        System.Drawing.Color timerColor;

        /* If there is no comparison time for this split, LiveSplit considers you 
        ahead, even if you are behind a later split */
        if (!vars.SplitHasComparisonTime(currSplitIndex))
        {
            timerColor = timer.LayoutSettings.AheadGainingTimeColor;
        }
        else
        {
            TimeSpan currSplitComparisonTime = (TimeSpan) timer.CurrentSplit.Comparisons[comparison][timingMethod];
            TimeSpan currTime = (TimeSpan) timer.CurrentTime[timingMethod];
            
            TimeSpan currSplitDelta = currTime - currSplitComparisonTime;
            TimeSpan prevSplitDelta = TimeSpan.Zero;

            if (prevDeltaIndex >= 0)
            {
                TimeSpan prevSplitSplitTime = (TimeSpan) timer.Run[prevDeltaIndex].SplitTime[timingMethod];
                TimeSpan prevSplitComparisonTime = (TimeSpan) timer.Run[prevDeltaIndex].Comparisons[comparison][timingMethod];

                prevSplitDelta = prevSplitSplitTime - prevSplitComparisonTime;
            }

            // the < is used deliberately to match the algorithm used by livesplit
            if (currSplitDelta < TimeSpan.Zero)
            {
                // the <= is used deliberately to match the algorithm used by livesplit
                if (currSplitDelta <= prevSplitDelta)
                {
                    timerColor = timer.LayoutSettings.AheadGainingTimeColor;
                }
                else
                {
                    timerColor = timer.LayoutSettings.AheadLosingTimeColor;
                }
            }
            else
            {
                // the < is used deliberately to match the algorithm used by livesplit
                if (currSplitDelta < prevSplitDelta)
                {
                    timerColor = timer.LayoutSettings.BehindGainingTimeColor;
                }
                else
                {
                    timerColor = timer.LayoutSettings.BehindLosingTimeColor;
                }
            }
        }

        return timerColor;
    });

    vars.SplitHasComparisonTime = (Func<int, bool>) ((splitIndex) =>
    {
        var comparison = timer.CurrentComparison;
        var timingMethod = timer.CurrentTimingMethod;

        TimeSpan? splitComparisonTime = timer.Run[splitIndex].Comparisons[comparison][timingMethod];
        
        bool hasComparisonTime = true;
        if (splitComparisonTime == null)
        {
            hasComparisonTime = false;
        }
        return hasComparisonTime;
    });

    vars.SplitHasSplitTime = (Func<int, bool>) ((splitIndex) =>
    {
        var timingMethod = timer.CurrentTimingMethod;

        TimeSpan? splitSplitTime = timer.Run[splitIndex].SplitTime[timingMethod];
        
        bool hasSplitTime = true;
        if (splitSplitTime == null)
        {
            hasSplitTime = false;
        }
        return hasSplitTime;
    });

    // I'd like this to not be O(n) but this is what works right now
    vars.GetPrevSplitWithDeltaIndex = (Func<int, int>) ((currSplitIndex) =>
    {
        int prevDeltaIndex = -1;
        
        for (int i = currSplitIndex - 1; i >= 0; i--)
        {
            if (vars.SplitHasComparisonTime(i) && vars.SplitHasSplitTime(i))
            {
                prevDeltaIndex = i;
                break;
            }
        }

        return prevDeltaIndex;
    });
}

init
{
    /* GET PTR FUNCS */

    vars.GetAOBRelativePtr = (Func<SignatureScanner, SigScanTarget, int, int, IntPtr>) ((scanner, sst, aobOffset, instructionLength) => 
    {
        IntPtr ptr = scanner.Scan(sst);
        int offset = memory.ReadValue<int>(ptr + aobOffset);
        return ptr + offset + instructionLength;
    });

    vars.GetLowestLevelPtr = (Func<DeepPointer, IntPtr>) ((deepPointer) => 
    {
        IntPtr tempPtr = (IntPtr) 0;

        while(!deepPointer.DerefOffsets(game, out tempPtr))
        {
            Thread.Sleep(500);
        }

        return tempPtr;
    });

    /* GAME SPECIFIC ADDRESSES AND OFFSETS */

    SignatureScanner sigScanner = new SignatureScanner(game, modules.First().BaseAddress, modules.First().ModuleMemorySize);

    if (game.ProcessName.ToString() == "DARKSOULS")
    {
        SigScanTarget playerAOB = new SigScanTarget(0, "A1 ?? ?? ?? ?? 8B 40 34 53 32");
        IntPtr playerPtr = (IntPtr) memory.ReadValue<int>(sigScanner.Scan(playerAOB) + 1);
        
        vars.HairRedDeepPtr = new DeepPointer(playerPtr, 0x08, 0x380);
        vars.HairGreenDeepPtr = new DeepPointer(playerPtr, 0x08, 0x384);
        vars.HairBlueDeepPtr = new DeepPointer(playerPtr, 0x08, 0x388);
    }
    else if (game.ProcessName.ToString() == "DarkSoulsRemastered")
    {
        SigScanTarget playerAOB = new SigScanTarget(0, "48 8B 05 ?? ?? ?? ?? 45 33 ED 48 8B F1 48 85 C0");
        IntPtr playerPtr = vars.GetAOBRelativePtr(sigScanner, playerAOB, 3, 7);
        
        vars.HairRedDeepPtr = new DeepPointer(playerPtr, 0x10, 0x4C0);
        vars.HairGreenDeepPtr = new DeepPointer(playerPtr, 0x10, 0x4C4);
        vars.HairBlueDeepPtr = new DeepPointer(playerPtr, 0x10, 0x4C8);
    }

    /* GET PTRS */

    vars.HairRedPtr = vars.GetLowestLevelPtr(vars.HairRedDeepPtr);
    vars.HairGreenPtr = vars.GetLowestLevelPtr(vars.HairGreenDeepPtr);
    vars.HairBluePtr = vars.GetLowestLevelPtr(vars.HairBlueDeepPtr);

    /* READ AND WRITE HAIR COLOR TO MEMORY */

    vars.WriteHairColorToMemory = (Action<float[]>) ((hairRGB) =>
    {
        float hairR = hairRGB[0];
        float hairG = hairRGB[1];
        float hairB = hairRGB[2];

        IntPtr hairRedPtr = vars.HairRedPtr;
        game.WriteBytes(hairRedPtr, BitConverter.GetBytes(hairR));
       
        IntPtr hairGreenPtr = vars.HairGreenPtr;
        game.WriteBytes(hairGreenPtr, BitConverter.GetBytes(hairG));
       
        IntPtr hairBluePtr = vars.HairBluePtr;
        game.WriteBytes(hairBluePtr, BitConverter.GetBytes(hairB));
    });

    vars.GetHairColorFromMemory = (Func<float[]>) (() =>
    {
        IntPtr hairRedPtr = vars.HairRedPtr;
        IntPtr hairGreenPtr = vars.HairGreenPtr;
        IntPtr hairBluePtr = vars.HairBluePtr;

        float hairR = memory.ReadValue<float>(hairRedPtr);
        float hairG = memory.ReadValue<float>(hairGreenPtr);
        float hairB = memory.ReadValue<float>(hairBluePtr);

        return new float[] {hairR, hairG, hairB};
    });
}

/* isLoading is used so that the following code only runs when the timer is 
running. It never returns true, so it never affects the timer */
isLoading
{
    int currSplitIndex = timer.CurrentSplitIndex;

    int prevDeltaIndex = vars.GetPrevSplitWithDeltaIndex(currSplitIndex);
    System.Drawing.Color timerColor = vars.GetCurrentTimerColor(prevDeltaIndex);

    if (!timerColor.Equals(vars.OldTimerColor))
    {
        vars.InitializeHairColorShift(timerColor);
    }
    vars.ShiftHairVars();
    vars.WriteHairColorToMemory(vars.CurrentHairColor);

    // save TimerColor to compare during next iteration
    vars.OldTimerColor = timerColor;
}
