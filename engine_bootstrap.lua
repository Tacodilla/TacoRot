-- engine_bootstrap.lua — safety net for class engines (3.3.5-safe)
-- Runs after all engine_* files listed in the TOC.
-- Previously this file contained a Hunter fallback, but each class now has a
-- dedicated engine. The bootstrap is kept as a placeholder for any future
-- safety nets that may be required.

local TR = _G.TacoRot
if not TR then return end

-- Placeholder for future fallback logic if a class engine fails to load.

