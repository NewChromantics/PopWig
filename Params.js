export const Params = {};
export default Params;

Params.SquareStep = true;
Params.DrawColour = true;
Params.DrawHeight = false;
Params.DrawStepHeat = false;
Params.DrawUv = false;
Params.ApplyAmbientOcclusionColour = true;
Params.StepHeatMax = 1.0;
Params.ApplyHeightColour = false;
Params.AmbientOcclusionMin = 0.31;
Params.AmbientOcclusionMax = 0.78;
Params.TextureSampleColourMult = 1.41;
Params.TextureSampleColourAdd = 0.1;
Params.BaseColour = [0.91,0.85,0.75];
Params.BackgroundColour = [0,0,0];
Params.TerrainHeightScalar = 0.074;
Params.Fov = 52;
Params.BrightnessMult = 1.8;
Params.HeightMapStepBack = 0.57;//0.30;
Params.MoonSphere = [0,1.6,0.2,0.5];
Params.DebugClearEyes = false;
Params.XrToMouseScale = 100;	//	metres to pixels


export const ParamsMeta = {};
ParamsMeta.TextureSampleColourMult = {min:0,max:2};
ParamsMeta.TextureSampleColourAdd = {min:-1,max:1};
ParamsMeta.AmbientOcclusionMin = {min:0,max:1};
ParamsMeta.AmbientOcclusionMax = {min:0,max:1};
ParamsMeta.BaseColour = {type:'Colour'};
ParamsMeta.BackgroundColour = {type:'Colour'};
ParamsMeta.TerrainHeightScalar = {min:0,max:5};
ParamsMeta.Fov = {min:10,max:90};
ParamsMeta.BrightnessMult = {min:0,max:10};
ParamsMeta.HeightMapStepBack = {min:0,max:1};
ParamsMeta.StepHeatMax = {min:0,max:1};

