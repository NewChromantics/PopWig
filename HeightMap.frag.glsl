precision highp float;

in vec2 uv;
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
uniform float3 BaseColour;
uniform float3 BackgroundColour;
uniform float TextureSampleColourMult;
uniform float TextureSampleColourAdd;
const bool FlipSample = true;

#define MAX_STEPS	20
#define FAR_Z		100.0

uniform float4 MoonSphere;// = float4(0,0,-3,1.0);

struct TRay
{
	vec3 Pos;
	vec3 Dir;
};

vec3 ScreenToWorld(float2 uv,float z)
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
void GetWorldRay(out float3 RayPos,out float3 RayDir)
{
	float Near = 0.01;
	float Far = FAR_Z;
	RayPos = ScreenToWorld( uv, Near );
	RayDir = ScreenToWorld( uv, Far ) - RayPos;
	
	//	gr: this is backwards!
	RayDir = -normalize( RayDir );
}

float Range(float Min,float Max,float Value)
{
	return (Value-Min) / (Max-Min);
}
float Range01(float Min,float Max,float Value)
{
	return clamp(0.0,1.0,Range(Min,Max,Value));
}

float3 NormalToRedGreen(float Normal)
{
	if ( Normal < 0.5 )
	{
		Normal /= 0.5;
		return float3( 1.0, Normal, 0.0 );
	}
	else
	{
		Normal -= 0.5;
		Normal /= 0.5;
		return float3( 1.0-Normal, 1.0, 0.0 );
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
float2 ViewToEquirect(float3 View3)
{
	View3 = normalize(View3);
	float2 longlat = float2(atan2(View3.x, View3.z) + PI, acos(-View3.y));
	
	//longlat.x += lerp( 0, UNITY_PI*2, Range( 0, 360, LatitudeOffset ) );
	//longlat.y += lerp( 0, UNITY_PI*2, Range( 0, 360, LongitudeOffset ) );
	
	float2 uv = longlat / float2(2.0 * PI, PI);
	
	if ( FlipSample )
		uv.y = 1.0 - uv.y;
	
	return uv;
}

void GetMoonHeightLocal(float3 MoonNormal,out float Height)
{
	float2 HeightmapUv = ViewToEquirect( MoonNormal );
	
	Height = texture2D( HeightmapTexture, HeightmapUv ).x;

	//	debug uv
	//Colour = float3( HeightmapUv, 0.5 );
	
	Height *= TerrainHeightScalar;
	
	/*
	float3 Rgb;
	float2 uv = HeightmapUv;
	if ( DrawColour )
		Rgb = texture2D( ColourTexture, uv ).xyz;
	else
		Rgb = float3( 1.0-uv.x, uv.y, 1.0 );
	
	if ( DrawHeight )
	{
		float Brightness = Height * (1.0 / TerrainHeightScalar);
		Rgb *= Brightness * BrightnessMult;
	}
	Colour = Rgb;
	*/
}


void GetMoonColourHeight(float3 MoonNormal,out float3 Colour,out float Height)
{
	GetMoonHeightLocal( MoonNormal, Height );
	float2 HeightmapUv = ViewToEquirect( MoonNormal );

	//	debug uv
	//Colour = float3( HeightmapUv, 0.5 );
	
	float3 Rgb = float3(1.0,1.0,1.0);
	float2 uv = HeightmapUv;
	if ( DrawColour )
	{
		Rgb = texture2D( ColourTexture, uv ).xyz;
		Rgb *= TextureSampleColourMult;
		Rgb += TextureSampleColourAdd;
	}
	else if ( DrawUv )
	{
		Rgb = float3( 1.0-uv.x, uv.y, 1.0 );
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




float DistanceToMoon(float3 Position)
{
	float3 DeltaToSurface = MoonSphere.xyz - Position;
	float3 Normal = -normalize( DeltaToSurface );
	float MoonRadius = MoonSphere.w;
	float3 MoonSurfacePoint = MoonSphere.xyz + Normal * MoonRadius;
	
	float Height;
	GetMoonHeightLocal( Normal, Height );
	
	MoonSurfacePoint += Normal * Height * MoonSphere.w;
	
	float Distance = length( Position - MoonSurfacePoint );
	
	//	do something more clever, like check against surface heights where the height could get in our way
	//	this scalar (where it works) is relative to the height, so maybe we can work that out...
	Distance *= HeightMapStepBack;
	
	return Distance;
}

float3 GetMoonColour(float3 Position)
{
	//	duplicate code!
	float3 DeltaToSurface = MoonSphere.xyz - Position;
	float3 Normal = -normalize( DeltaToSurface );
	float MoonRadius = MoonSphere.w;
	float3 MoonSurfacePoint = MoonSphere.xyz + Normal * MoonRadius;
	
	float Height;
	float3 Colour;
	GetMoonColourHeight( Normal, Colour, Height );
	return Colour;
}




//	returns intersction pos, w=success
float4 RayMarchSpherePos(TRay Ray,out float StepHeat)
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
			return float4(Position,1);
		
		//	ray gone too far
		if (RayTime > MaxDistance)
			return float4(Position,0);
	}
	//	ray never got close enough
	StepHeat = 1.0;
	return float4(0,0,0,-1);
}


float4 RayMarchSphere(TRay Ray,out float StepHeat)
{
	float4 Intersection = RayMarchSpherePos( Ray, StepHeat );
	//if ( Intersection.w < 0.0 )
	//	return float4(1,0,0,0);
	
	float3 Colour = GetMoonColour( Intersection.xyz );
	return float4( Colour, Intersection.w );
}



void main()
{
	TRay Ray;
	GetWorldRay(Ray.Pos,Ray.Dir);
	float4 Colour = float4(BackgroundColour,0.0);
	
	float StepHeat;
	float4 SphereColour = RayMarchSphere( Ray, StepHeat );
	if ( DrawStepHeat )
		SphereColour.xyz = NormalToRedGreen( 1.0 - StepHeat );
	
	if ( ApplyAmbientOcclusionColour )
	{
		float Mult = Range01( AmbientOcclusionMin, AmbientOcclusionMax, 1.0-StepHeat );
		SphereColour.xyz *= Mult;
	}


	Colour = mix( Colour, SphereColour, max(0.0,SphereColour.w) );
	gl_FragColor = Colour;
}

