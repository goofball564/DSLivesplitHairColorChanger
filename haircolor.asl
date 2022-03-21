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

    settings.Add("notRunning", false, "Also Enable When Timer Isn't Running");
    settings.Add("splitsColor", false, "Change Hair to Color of Last Split Instead of Current Timer Color");
    settings.Add("noRainbow", false, "Don't Change Hair to Rainbow Colors", "splitsColor");
    settings.SetToolTip("noRainbow", "If previous split is a rainbow color, hair will turn to your Best Segment (Gold) color.");

    //  Stopwatch used in Init block.
    vars.CooldownStopwatch = new Stopwatch();

    /* LIVESPLIT VARS */

    vars.OldColor = new System.Drawing.Color();
    vars.SplitIsRainbowColor = false;

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
        vars.CurrentHairColor = vars.ReadHairColorFromMemory();
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

    /* TIMER AND SPLIT COLOR FUNCS */

    // This is copy-pasted from the source code of the timer component (as it was on 2022-03-20)
    // So um, this part of the code has to be covered by the MIT License I Guess.
    // Lawyers, please make it so.
    vars.GetCurrentTimerColor = (Func<System.Drawing.Color>) (() =>
    {
        System.Drawing.Color timerColor = timer.LayoutSettings.TextColor;
        var comparison = timer.CurrentComparison;
        var timingMethod = timer.CurrentTimingMethod;

        if (timer.CurrentPhase == TimerPhase.NotRunning || timer.CurrentTime[timingMethod] < TimeSpan.Zero)
        {
            timerColor = timer.LayoutSettings.NotRunningColor;
        }
        else if (timer.CurrentPhase == TimerPhase.Paused)
        {
            timerColor = timer.LayoutSettings.PausedColor;
        }
        else if (timer.CurrentPhase == TimerPhase.Ended)
        {
            if (timer.Run.Last().Comparisons[comparison][timingMethod] == null || timer.CurrentTime[timingMethod] < timer.Run.Last().Comparisons[comparison][timingMethod])
            {
                timerColor = timer.LayoutSettings.PersonalBestColor;
            }
            else
            {
                timerColor = timer.LayoutSettings.BehindLosingTimeColor;
            }
        }
        else if (timer.CurrentPhase == TimerPhase.Running)
        {
            if (timer.CurrentSplit.Comparisons[comparison][timingMethod] != null)
            {
                timerColor = LiveSplitStateHelper.GetSplitColor(timer, timer.CurrentTime[timingMethod] - timer.CurrentSplit.Comparisons[comparison][timingMethod],
                    timer.CurrentSplitIndex, true, false, comparison, timingMethod)
                    ?? timer.LayoutSettings.AheadGainingTimeColor;
            }
            else
            {
                timerColor = timer.LayoutSettings.AheadGainingTimeColor;
            }
        }

        return timerColor;
    });

    vars.GetPreviousSplitColor = (Func<System.Drawing.Color>) (() =>
    {
        int previousSplitIndex = timer.CurrentSplitIndex - 1;
        System.Drawing.Color color = timer.LayoutSettings.TextColor;
        
        if (previousSplitIndex < 0)
        {
            color = vars.GetCurrentTimerColor();
        }
        else
        {
            var split = timer.Run[previousSplitIndex];
            var comparison = timer.CurrentComparison;
            var timingMethod = timer.CurrentTimingMethod;

            TimeSpan? deltaTime = split.SplitTime[timingMethod] - split.Comparisons[comparison][timingMethod];
            
            
            color = LiveSplitStateHelper.GetSplitColor(timer, deltaTime, previousSplitIndex, true, true, comparison, timingMethod) ?? timer.LayoutSettings.TextColor;
        }

        return color;
    });

    vars.IsPreviousSplitBestSegment = (Func<bool>) (() =>
    {
        bool returnVal = false;

        int previousSplitIndex = timer.CurrentSplitIndex - 1;
        var timingMethod = timer.CurrentTimingMethod;
        if (previousSplitIndex >= 0)
            returnVal = LiveSplitStateHelper.CheckBestSegment(timer, previousSplitIndex, timingMethod);
        else
            returnVal = false;
        
        return returnVal;
    });

    // Reimplementation of Rainbow Color from livesplit, but with smoother
    // transitions 
    vars.GetRainbowColor = (Func<System.Drawing.Color>) (() =>
    {
        var hue = (((int)DateTime.Now.TimeOfDay.TotalMilliseconds / 10) % 360);
        System.Drawing.Color rainbowColor = vars.HSVToColor(hue, 1, 1);
        return System.Drawing.Color.FromArgb((rainbowColor.R*2 + 255) / 3, (rainbowColor.G*2 + 255) / 3, (rainbowColor.B*2 + 255) / 3);
    });

    vars.HSVToColor = (Func<double, double, double, System.Drawing.Color>) ((H, S, V) =>
    {
        double C = V  * S;
        double X = C * ( 1 - Math.Abs( (H / 60) % 2 - 1 ) );
        double m = V - C;

        double[] rgb = new double[3];

        if (H >= 0 && H < 60)
            rgb = new double[] {C, X, 0};
        else if (H >= 60 && H < 120)
            rgb = new double[] {X, C, 0};
        else if (H >= 120 && H < 180)
            rgb = new double[] {0, C, X};
        else if (H >= 180 && H < 240)
            rgb = new double[] {0, X, C};
        else if (H >= 240 && H < 300)
            rgb = new double[] {X, 0, C};
        else
            rgb = new double[] {C, 0, X};

        for (int i = 0; i < rgb.Length; i++)
        {
            rgb[i] = Math.Round((rgb[i] + m) * 255);
        }

        return System.Drawing.Color.FromArgb((int)Math.Round(rgb[0]), (int)Math.Round(rgb[1]), (int)Math.Round(rgb[2]));
    });
}

init
{
    /* GET PTR FUNCS */

    vars.GetAOBRelativePtr = (Func<SignatureScanner, SigScanTarget, int, IntPtr>) ((scanner, sst, instructionLength) => 
    {
        int aobOffset = sst.Signatures[0].Offset;

        IntPtr ptr = scanner.Scan(sst);
        if (ptr == default(IntPtr))
        {
            throw new Exception("AOB Scan Unsuccessful");
        }

        int offset = memory.ReadValue<int>(ptr);

        return ptr - aobOffset + offset + instructionLength;
    });

    // Needs to have same signature as other AOB Ptr Func; ignoredValue is ignored.
    vars.GetAOBAbsolutePtr = (Func<SignatureScanner, SigScanTarget, int, IntPtr>) ((scanner, sst, ignoredValue) => 
    {
        IntPtr ptr = scanner.Scan(sst);
        if (ptr == default(IntPtr))
        {
            throw new Exception("AOB Scan Unsuccessful");
        }

        IntPtr tempPtr;
        if (!game.ReadPointer(ptr, out tempPtr))
        {
            throw new Exception("AOB scan did not yield valid pointer");
        }

        return tempPtr;
    });

    /* GAME SPECIFIC AOBs AND OFFSETS */

    SignatureScanner sigScanner = new SignatureScanner(game, modules.First().BaseAddress, modules.First().ModuleMemorySize);

    if (game.ProcessName.ToString() == "DARKSOULS")
    {
        vars.PlayerAOB = new SigScanTarget(1, "A1 ?? ?? ?? ?? 8B 40 34 53 32");

        vars.GetAOBPtr = vars.GetAOBAbsolutePtr;

        vars.HairRedOffsets = new int[] {0x8, 0x380};
        vars.HairGreenOffsets = new int[] {0x8, 0x384};
        vars.HairBlueOffsets = new int[] {0x8, 0x388};
    }
    else if (game.ProcessName.ToString() == "DarkSoulsRemastered")
    {
        vars.PlayerAOB = new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 45 33 ED 48 8B F1 48 85 C0");

        vars.GetAOBPtr = vars.GetAOBRelativePtr;

        vars.HairRedOffsets = new int[] {0x10, 0x4C0};
        vars.HairGreenOffsets = new int[] {0x10, 0x4C4};
        vars.HairBlueOffsets = new int[] {0x10, 0x4C8};
    }

    /* GET BASE POINTERS */

    /* Stopwatch is defined in startup block and is used to mimic
    Thread.Sleep without locking the Livesplit UI; 
    If an AOB scan fails, retry after a specified number of milliseconds
     */
    if (!vars.CooldownStopwatch.IsRunning || vars.CooldownStopwatch.ElapsedMilliseconds > vars.MillisecondsToWait)
    {
        vars.CooldownStopwatch.Start();
        try 
        {
            vars.PlayerPtr = vars.GetAOBPtr(sigScanner, vars.PlayerAOB, 7);
        }
        catch (Exception e)
        {
            vars.CooldownStopwatch.Restart();
            throw new Exception(e.ToString() + "\ninit {} needs to be recalled; base pointer creation unsuccessful");
        }
    }
    else
    {
        throw new Exception("init {} needs to be recalled; waiting to rescan for base pointers");
    }

    vars.CooldownStopwatch.Reset();

    /* DEFINE DEEP POINTERS */

    vars.HairRedDeepPtr = new DeepPointer(vars.PlayerPtr, vars.HairRedOffsets);
    vars.HairGreenDeepPtr = new DeepPointer(vars.PlayerPtr, vars.HairGreenOffsets);
    vars.HairBlueDeepPtr = new DeepPointer(vars.PlayerPtr, vars.HairBlueOffsets);

    /* READ AND WRITE HAIR COLOR TO MEMORY FUNCS */

    vars.WriteHairColorToMemory = (Action<float[]>) ((hairRGB) =>
    {
        float hairR = hairRGB[0];
        float hairG = hairRGB[1];
        float hairB = hairRGB[2];

        IntPtr hairRedPtr = IntPtr.Zero;
        IntPtr hairGreenPtr = IntPtr.Zero;
        IntPtr hairBluePtr = IntPtr.Zero;
        if (vars.HairRedDeepPtr.DerefOffsets(game, out hairRedPtr) 
        && vars.HairGreenDeepPtr.DerefOffsets(game, out hairGreenPtr) 
        && vars.HairBlueDeepPtr.DerefOffsets(game, out hairBluePtr))
        {
            game.WriteBytes(hairRedPtr, BitConverter.GetBytes(hairR));
            game.WriteBytes(hairGreenPtr, BitConverter.GetBytes(hairG));
            game.WriteBytes(hairBluePtr, BitConverter.GetBytes(hairB));
        }
    });

    vars.ReadHairColorFromMemory = (Func<float[]>) (() =>
    {
        float hairR = 0;
        float hairG = 0;
        float hairB = 0;

        if (vars.HairRedDeepPtr.Deref<float>(game, out hairR) 
        && vars.HairGreenDeepPtr.Deref<float>(game, out hairG) 
        && vars.HairBlueDeepPtr.Deref<float>(game, out hairB))
        {
            return new float[] {hairR, hairG, hairB};
        }
        else
        {
            return vars.CurrentHairColor;
        }
    });
}

update
{
    current.SplitIndex = timer.CurrentSplitIndex;

    if (timer.CurrentPhase == TimerPhase.Running || settings["notRunning"])
    {
        System.Drawing.Color color = new System.Drawing.Color();
        if (settings["splitsColor"])
        {
            color = vars.GetPreviousSplitColor();
        }
        else
        {
            color = vars.GetCurrentTimerColor();
        }

        vars.SplitIsRainbowColor = settings["splitsColor"] && timer.LayoutSettings.ShowBestSegments && timer.LayoutSettings.UseRainbowColor && vars.IsPreviousSplitBestSegment();

        if (vars.SplitIsRainbowColor)
        {
            if (settings["noRainbow"])
            {
                color = timer.LayoutSettings.BestSegmentColor;

                if (!color.Equals(vars.OldColor))
                {
                    vars.InitializeHairColorShift(color);
                }
                vars.ShiftHairVars();
            }
            // If we're showing a rainbow color,
            // hair is set in real time to continually changing return value 
            // of vars.GetRainbowColor(), instead of shifting
            // between two different values ourselves.
            else
            {
                color = vars.GetRainbowColor();
                vars.SetHairVars(color);
            }
        }
        else
        {
            if (!color.Equals(vars.OldColor))
            {
                vars.InitializeHairColorShift(color);
            }
            vars.ShiftHairVars();
        }

        vars.WriteHairColorToMemory(vars.CurrentHairColor);

        // save color to compare during next iteration
        vars.OldColor = color;

        vars.FirstIteration = false;
    }
}
