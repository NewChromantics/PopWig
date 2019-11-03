Pop.Include = function(Filename)
{
	let Source = Pop.LoadFileAsString(Filename);
	return Pop.CompileAndRun( Source, Filename );
}

//	auto setup global
function SetGlobal()
{
	Pop.Global = this;
	Pop.Debug(Pop.Global);
}
SetGlobal.call(this);


const RenderHeightmapShader = RegisterShaderAssetFilename('HeightMap.frag.glsl','Quad.vert.glsl');

const Colour4kFilename = 'lroc_color_poles_4k.jpg';
const Colour16kFilename = 'lroc_color_poles_16k.jpg';
const HeightmapFilename = 'ldem_16_uint.jpg';
Pop.AsyncCacheAssetAsString('HeightMap.frag.glsl');
Pop.AsyncCacheAssetAsString('Quad.vert.glsl');
Pop.AsyncCacheAssetAsImage(HeightmapFilename);
Pop.AsyncCacheAssetAsImage(Colour4kFilename);
Pop.AsyncCacheAssetAsImage(Colour16kFilename);



var Params = {};
function OnParamsChanged()
{
	
}
Params.SquareStep = true;
Params.DrawColour = true;
Params.DrawHeight = true;
Params.BigImage = false;
Params.TerrainHeightScalar = 1.70;
Params.PositionToHeightmapScale = 0.009;
Params.Fov = 52;
Params.BrightnessMult = 1.8;
Params.HeightMapStepBack = 0.23;

const ParamsWindowRect = [1200,20,350,200];
var ParamsWindow = new CreateParamsWindow(Params,OnParamsChanged,ParamsWindowRect);
ParamsWindow.AddParam('SquareStep');
ParamsWindow.AddParam('DrawColour');
ParamsWindow.AddParam('DrawHeight');
ParamsWindow.AddParam('BigImage');
ParamsWindow.AddParam('TerrainHeightScalar',0.001,5);
ParamsWindow.AddParam('PositionToHeightmapScale',0,1);
ParamsWindow.AddParam('TerrainHeightScalar',0,5);
ParamsWindow.AddParam('Fov',10,90);
ParamsWindow.AddParam('BrightnessMult',0,3);
ParamsWindow.AddParam('HeightMapStepBack',0,1);


class TMoonApp
{
	constructor()
	{
		this.Camera = new Pop.Camera();
		//this.Camera.LookAt = [71.5,-5,-30.3];
		//this.Camera.Position = [69.8,3.35,-48.7];

	}
}


const RandomNumberCache = [];

function GetRandomNumberArray(Count)
{
	if ( RandomNumberCache.length < Count )
		Pop.Debug("calculating random numbers x"+Count);
	while ( RandomNumberCache.length < Count )
	{
		RandomNumberCache.push( Math.random() );
	}
	return RandomNumberCache;
}


function CreateRandomSphereImage(Width,Height)
{
	let Channels = 4;
	let Format = 'Float4';
	
	const TimerStart = Pop.GetTimeNowMs();
	
	let Pixels = new Float32Array( Width * Height * Channels );
	const Rands = GetRandomNumberArray(Pixels.length*Channels);
	for ( let i=0;	i<Pixels.length;	i+=Channels )
	{
		let xyz = Rands.slice( i*Channels, (i*Channels)+Channels );
		let w = xyz[3];
		xyz = Math.Subtract3( xyz, [0.5,0.5,0.5] );
		xyz = Math.Normalise3( xyz );
		xyz = Math.Add3( xyz, [1,1,1] );
		xyz = Math.Multiply3( xyz, [0.5,0.5,0.5] );
		
		Pixels[i+0] = xyz[0];
		Pixels[i+1] = xyz[1];
		Pixels[i+2] = xyz[2];
		Pixels[i+3] = w;
	}
	
	Pop.Debug("CreateRandomSphereImage() took", Pop.GetTimeNowMs() - TimerStart);
	
	let Texture = new Pop.Image();
	Texture.WritePixels( Width, Height, Pixels, Format );
	return Texture;
}

const MoonApp = new TMoonApp();
//let MoonHeightmap = CreateRandomSphereImage(32,32);
//op.AsyncCacheAssetAsString('Quad.vert.glsl');
let MoonHeightmap = null;
let MoonColour4k = null;
let MoonColour16k = null;



function Render(RenderTarget)
{
	if ( !MoonHeightmap )
	{
		MoonHeightmap = new Pop.Image(HeightmapFilename);
		MoonHeightmap.SetLinearFilter(true);
	}
	
	let MoonColour;
	if ( Params.BigImage )
	{
		if ( !MoonColour16k )
		{
			MoonColour16k = new Pop.Image(Colour16kFilename);
			MoonColour16k.SetLinearFilter(true);
		}
		MoonColour = MoonColour16k;
	}
	else
	{
		if ( !MoonColour4k )
		{
			MoonColour4k = new Pop.Image(Colour4kFilename);
			MoonColour4k.SetLinearFilter(true);
		}
		MoonColour = MoonColour4k;
	}

	MoonApp.Camera.FovVertical = Params.Fov;
	
	
	RenderTarget.ClearColour( 0,1.0,0 );
	const Quad = GetAsset('Quad',RenderTarget);
	const Shader = GetAsset(RenderHeightmapShader,RenderTarget);
	const Camera = MoonApp.Camera;
	const WorldToCameraMatrix = Camera.GetWorldToCameraMatrix();
	const CameraProjectionMatrix = Camera.GetProjectionMatrix( RenderTarget.GetScreenRect() );
	const ScreenToCameraTransform = Math.MatrixInverse4x4( CameraProjectionMatrix );
	const CameraToWorldTransform = Math.MatrixInverse4x4( WorldToCameraMatrix );
	const LocalToWorldTransform = Camera.GetLocalToWorldFrustumTransformMatrix();
	//const LocalToWorldTransform = Math.CreateIdentityMatrix();
	const WorldToLocalTransform = Math.MatrixInverse4x4(LocalToWorldTransform);
	//Pop.Debug("Camera frustum LocalToWorldTransform",LocalToWorldTransform);
	//Pop.Debug("Camera frustum WorldToLocalTransform",WorldToLocalTransform);
	const SetUniforms = function(Shader)
	{
		Shader.SetUniform('VertexRect',[0,0,1,1.0]);
		Shader.SetUniform('ScreenToCameraTransform',ScreenToCameraTransform);
		Shader.SetUniform('CameraToWorldTransform',CameraToWorldTransform);
		Shader.SetUniform('LocalToWorldTransform',LocalToWorldTransform);
		Shader.SetUniform('WorldToLocalTransform',WorldToLocalTransform);
		Shader.SetUniform('HeightmapTexture',MoonHeightmap);
		Shader.SetUniform('ColourTexture',MoonColour);
		
		function SetUniform(Key)
		{
			Shader.SetUniform( Key, Params[Key] );
		}
		Object.keys(Params).forEach(SetUniform);
	}
	//RenderTarget.EnableBlend(true);
	RenderTarget.DrawGeometry( Quad, Shader, SetUniforms );

}


//	window now shared from bootup
const Window = new Pop.Opengl.Window("Lunar");

Window.OnRender = function(RenderTarget)
{
	try
	{
		Render(RenderTarget);
	}
	catch(e)
	{
		console.warn(e);
	}
}

MoveCamera = function(x,y,Button,FirstDown)
{
	const Camera = MoonApp.Camera;
	
	//if ( Button == 0 )
	//	this.Camera.OnCameraPan( x, 0, y, FirstDown );
	if ( Button == 1 )
		Camera.OnCameraOrbit( x, y, 0, FirstDown );
	if ( Button == 2 )
		Camera.OnCameraPanLocal( x, y, 0, FirstDown );
	if ( Button == 0 )
		Camera.OnCameraPanLocal( x, 0, y, FirstDown );
}

Window.OnMouseDown = function(x,y,Button)
{
	MoveCamera( x,y,Button,true );
}

Window.OnMouseMove = function(x,y,Button)
{
	MoveCamera( x,y,Button,false );
}

Window.OnMouseScroll = function(x,y,Button,Delta)
{
	let Fly = Delta[1] * 50;
	//Fly *= Params.ScrollFlySpeed;

	const Camera = MoonApp.Camera;
	Camera.OnCameraPanLocal( 0, 0, 0, true );
	Camera.OnCameraPanLocal( 0, 0, Fly, false );
}

