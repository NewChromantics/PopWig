precision highp float;

varying vec2 uv;
uniform mat4 ScreenToCameraTransform;
uniform mat4 CameraToWorldTransform;

uniform float TerrainHeightScalar;
uniform sampler2D HeightmapTexture;
uniform sampler2D ColourTexture;
uniform bool SquareStep;
uniform bool DrawColour;
uniform bool DrawHeight;
uniform bool DrawStepHeat;
uniform bool DrawUv;
uniform bool ApplyAmbientOcclusionColour;
uniform bool ApplyHeightColour;
uniform float AmbientOcclusionMin;
uniform float AmbientOcclusionMax;
uniform float BrightnessMult;
uniform float HeightMapStepBack;
uniform vec3 BaseColour;
uniform vec3 BackgroundColour;
uniform float TextureSampleColourMult;
uniform float TextureSampleColourAdd;
const bool FlipSample = true;
uniform float StepHeatMax;
#define MAX_STEPS	30
#define FAR_Z		10.0
//	bodge as AO colour was tweaked with 40 steps
#define STEPHEAT_MAX	( StepHeatMax / (float(MAX_STEPS)/40.0) )

uniform vec4 MoonSphere;// = vec4(0,0,-3,1.0);

struct TRay
{
	vec3 Pos;
	vec3 Dir;
};

vec3 ScreenToWorld(vec2 uv,float z)
{
	float x = mix( -1.0, 1.0, uv.x );
	float y = mix( 1.0, -1.0, uv.y );
	vec4 ScreenPos4 = vec4( x, y, z, 1.0 );
	vec4 CameraPos4 = ScreenToCameraTransform * ScreenPos4;
	vec4 WorldPos4 = CameraToWorldTransform * CameraPos4;
	vec3 WorldPos = WorldPos4.xyz / WorldPos4.w;
	
	return WorldPos;
}

//	gr: returning a TRay, or using TRay as an out causes a very low-precision result...
void GetWorldRay(out vec3 RayPos,out vec3 RayDir)
{
	float Near = 0.01;
	float Far = FAR_Z;
	RayPos = ScreenToWorld( uv, Near );
	RayDir = ScreenToWorld( uv, Far ) - RayPos;
	
	//	gr: this is backwards!
	RayDir = -normalize( RayDir );
	
	//	mega bodge for webxr views
	//	but, there's something wrong with when we pan (may be using old broken camera code)
	/*
	if ( RayDir.z < 0.0 )
	{
		RayDir *= -1.0;
	}
	*/
}

float Range(float Min,float Max,float Value)
{
	return (Value-Min) / (Max-Min);
}
float Range01(float Min,float Max,float Value)
{
	return clamp(Range(Min,Max,Value),0.0,1.0);
}

vec3 NormalToRedGreen(float Normal)
{
	if ( Normal < 0.5 )
	{
		Normal /= 0.5;
		return vec3( 1.0, Normal, 0.0 );
	}
	else
	{
		Normal -= 0.5;
		Normal /= 0.5;
		return vec3( 1.0-Normal, 1.0, 0.0 );
	}
}


vec3 GetRayPositionAtTime(TRay Ray,float Time)
{
	return Ray.Pos + ( Ray.Dir * Time );
}


#define PI 3.14159265359

float atan2(float x,float y)
{
	return atan( y, x );
}


//	https://github.com/SoylentGraham/PopUnityCommon/blob/master/PopCommon.cginc#L298
vec2 ViewToEquirect(vec3 View3)
{
	View3 = normalize(View3);
	vec2 longlat = vec2(atan2(View3.x, View3.z) + PI, acos(-View3.y));
	
	//longlat.x += lerp( 0, UNITY_PI*2, Range( 0, 360, LatitudeOffset ) );
	//longlat.y += lerp( 0, UNITY_PI*2, Range( 0, 360, LongitudeOffset ) );
	
	vec2 uv = longlat / vec2(2.0 * PI, PI);
	
	if ( FlipSample )
		uv.y = 1.0 - uv.y;
	
	return uv;
}

void GetMoonHeightLocal(vec3 MoonNormal,out float Height)
{
	vec2 HeightmapUv = ViewToEquirect( MoonNormal );
	
	Height = texture2D( HeightmapTexture, HeightmapUv ).x;

	//	debug uv
	//Colour = vec3( HeightmapUv, 0.5 );
	
	Height *= TerrainHeightScalar;
	
	/*
	vec3 Rgb;
	vec2 uv = HeightmapUv;
	if ( DrawColour )
		Rgb = texture2D( ColourTexture, uv ).xyz;
	else
		Rgb = vec3( 1.0-uv.x, uv.y, 1.0 );
	
	if ( DrawHeight )
	{
		float Brightness = Height * (1.0 / TerrainHeightScalar);
		Rgb *= Brightness * BrightnessMult;
	}
	Colour = Rgb;
	*/
}


void GetMoonColourHeight(vec3 MoonNormal,out vec3 Colour,out float Height)
{
	GetMoonHeightLocal( MoonNormal, Height );
	vec2 HeightmapUv = ViewToEquirect( MoonNormal );

	//	debug uv
	//Colour = vec3( HeightmapUv, 0.5 );
	
	vec3 Rgb = vec3(1.0,1.0,1.0);
	vec2 uv = HeightmapUv;
	if ( DrawColour )
	{
		Rgb = texture2D( ColourTexture, uv ).xyz;
		Rgb *= TextureSampleColourMult;
		Rgb += TextureSampleColourAdd;
	}
	else if ( DrawUv )
	{
		Rgb = vec3( 1.0-uv.x, uv.y, 1.0 );
	}
	else if ( DrawHeight )
	{
		Rgb = NormalToRedGreen(Height);
	}

	Rgb *= BaseColour;
	
	if ( ApplyHeightColour )
	{
		float Brightness = Height * (1.0 / TerrainHeightScalar);
		Rgb *= Brightness;
	}
	Colour = Rgb;
}




float DistanceToMoon(vec3 Position)
{
	vec3 DeltaToSurface = MoonSphere.xyz - Position;
	vec3 Normal = -normalize( DeltaToSurface );
	float MoonRadius = MoonSphere.w;
	vec3 MoonSurfacePoint = MoonSphere.xyz + Normal * MoonRadius;
	
	float Height;
	GetMoonHeightLocal( Normal, Height );
	
	MoonSurfacePoint += Normal * Height * MoonSphere.w;
	
	float Distance = length( Position - MoonSurfacePoint );
	
	//	do something more clever, like check against surface heights where the height could get in our way
	//	this scalar (where it works) is relative to the height, so maybe we can work that out...
	Distance *= HeightMapStepBack;
	
	return Distance;
}

vec3 GetMoonColour(vec3 Position)
{
	//	duplicate code!
	vec3 DeltaToSurface = MoonSphere.xyz - Position;
	vec3 Normal = -normalize( DeltaToSurface );
	float MoonRadius = MoonSphere.w;
	vec3 MoonSurfacePoint = MoonSphere.xyz + Normal * MoonRadius;
	
	float Height;
	vec3 Colour;
	GetMoonColourHeight( Normal, Colour, Height );
	return Colour;
}




//	returns intersction pos, w=success
vec4 RayMarchSpherePos(TRay Ray,out float StepHeat)
{
	const float MinDistance = 0.001;
	const float CloseEnough = MinDistance;
	const float MinStep = MinDistance;
	const float MaxDistance = FAR_Z;
	const int MaxSteps = MAX_STEPS;
	
	//	start close
	float RayTime = DistanceToMoon( Ray.Pos );//0.01;
	
	for ( int s=0;	s<MaxSteps;	s++ )
	{
		StepHeat = float(s)/float(MaxSteps);
		vec3 Position = Ray.Pos + Ray.Dir * RayTime;
		float MoonDistance = DistanceToMoon( Position );
		float HitDistance = MoonDistance;
		
		//RayTime += max( HitDistance, MinStep );
		RayTime += HitDistance;
		if ( HitDistance < CloseEnough )
			return vec4(Position,1);
		
		//	ray gone too far
		if (RayTime > MaxDistance)
			return vec4(Position,0);
	}
	//	ray never got close enough
	StepHeat = 1.0;
	return vec4(0,0,0,-1);
}


vec4 RayMarchSphere(TRay Ray,out float StepHeat)
{
	vec4 Intersection = RayMarchSpherePos( Ray, StepHeat );
	//if ( Intersection.w < 0.0 )
	//	return vec4(1,0,0,0);
	
	vec3 Colour = GetMoonColour( Intersection.xyz );
	return vec4( Colour, Intersection.w );
}



void main()
{
	//gl_FragColor = vec4(uv,0,1);
	//return;
	TRay Ray;
	GetWorldRay(Ray.Pos,Ray.Dir);
	vec4 Colour = vec4(BackgroundColour,0.0);
	
	//gl_FragColor = vec4(Ray.Dir,1.0);
	//return;
	
	float StepHeat;
	vec4 SphereColour = RayMarchSphere( Ray, StepHeat );
	StepHeat = min( 1.0, StepHeat / STEPHEAT_MAX );
	if ( DrawStepHeat )
		SphereColour.xyz = NormalToRedGreen( 1.0 - StepHeat );
	
	if ( ApplyAmbientOcclusionColour )
	{
		float Mult = Range01( AmbientOcclusionMin, AmbientOcclusionMax, 1.0-StepHeat );
		SphereColour.xyz *= Mult;
	}


	Colour = mix( Colour, SphereColour, max(0.0,SphereColour.w) );
	//Colour.xy = uv;
	Colour.w = 1.0;
	gl_FragColor = Colour;
}

