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
uniform float Shadowk;	//	=1.70
uniform float BounceSurfaceDistance;

uniform float LightX;
uniform float LightY;
uniform float LightZ;
uniform float LightRadius;
uniform float ShadowHardness;
#define WorldLightPosition	vec3(LightX,LightY,LightZ)
#define LightSphere	vec4(LightX,LightY,LightZ,LightRadius)

#define MAX_STEPS	70
#define FAR_Z		200.0
#define FAR_Z_EPSILON	(FAR_Z-0.01)
//	bodge as AO colour was tweaked with 40 steps
#define STEPHEAT_MAX	( StepHeatMax / (float(MAX_STEPS)/40.0) )

uniform float FloorY;
uniform float WallZ;
uniform float HeadX;
uniform float HeadY;
uniform float HeadZ;
uniform float HeadRadius;
#define HeadSphere	vec4(HeadX,HeadY,HeadZ,HeadRadius)
#define WorldUp	vec3(0,1,0)
#define WorldForward	vec3(0,0,1)	


#define GIZMO_NONE 0
#define GIZMO_LIGHT	1

uniform float VignettePow;


float Distance(vec3 a,vec3 b)
{
	return length( a - b );
}


vec3 ApplyGizmoColour(int Gizmo,vec3 CurrentColour)
{
	if ( Gizmo == 0 )
		return CurrentColour;
	
	return vec3(1,1,1);
}

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





float sdSphere(vec3 Position,vec4 Sphere)
{
	return length( Position-Sphere.xyz )-Sphere.w;
}

float sdPlane( vec3 p, vec3 n, float h )
{
	// n must be normalized
	n = normalize(n);
	return dot(p,n) + h;
}


//vec2 sdFloor(vec3 Position,vec3 Direction)
float sdFloor(vec3 Position,vec3 Direction)
{
	//return vec2(999.0,0.0);//	should fail to render a floor
	float d = sdPlane(Position,WorldUp,FloorY);
	float tp1 = ( Position.y <= FloorY ) ? 1.0 : 0.0;
	/*
	 float tp1 = (Position.y-FloorY)/Direction.y;
	 if ( tp1 > 0.0 )
	 {
	 //d = tp1;	//	gr: why is sdPlane distance wrong? but right in map() 
	 tp1 = 1.0;
	 }
	 else
	 {
	 //d = 99.9;
	 tp1 = 0.0;
	 }
	 */
	//return vec2(d,tp1);
	return d;
}

float sdWall(vec3 Position,vec3 Direction)
{
	//return vec2(999.0,0.0);//	should fail to render a floor
	float d = sdPlane(Position,WorldForward,WallZ);
	//float tp1 = ( Position.z <= WallZ ) ? 1.0 : 0.0;
	/*
	 float tp1 = (Position.y-FloorY)/Direction.y;
	 if ( tp1 > 0.0 )
	 {
	 //d = tp1;	//	gr: why is sdPlane distance wrong? but right in map() 
	 tp1 = 1.0;
	 }
	 else
	 {
	 //d = 99.9;
	 tp1 = 0.0;
	 }
	 */
	//return vec2(d,tp1);
	return d;
}

float DistanceToScene(vec3 Position,vec3 RayDirection)
{
	vec4 OriginSphere = HeadSphere;
	
	float Dist = FAR_Z;
	
	Dist = min( Dist, sdSphere(Position,OriginSphere) );
	Dist = min( Dist, sdFloor(Position,RayDirection) );
	Dist = min( Dist, sdWall(Position,RayDirection) );
	
	return Dist;
}

//	return gizmo code of an object in front of the current traced ray
int GetGizmo(TRay Ray,vec4 CurrentHitPosition)
{
	float DistanceToHit = distance( Ray.Pos, CurrentHitPosition.xyz ); 
	float DistanceToLight = sdSphere( Ray.Pos, LightSphere );

	if ( DistanceToLight < DistanceToHit )
	{
		//	move the ray, did it actually hit
		vec3 NearLightPos = Ray.Pos + Ray.Dir * DistanceToLight;
		DistanceToLight = sdSphere( NearLightPos, LightSphere );
		if ( DistanceToLight < 0.01 )
			return GIZMO_LIGHT;
	}
	
	return GIZMO_NONE;
}

//	returns hitpos,success
vec4 RayMarchScene(TRay Ray)
{
	const float MinDistance = 0.01;
	const float CloseEnough = MinDistance;
	const float MinStep = 0.0;//MinDistance;
	const float MaxDistance = FAR_Z_EPSILON;
	const int MaxSteps = MAX_STEPS;
	
	//	todo: raytrace wall/floor
	
	
	float RayTraversed = 0.0;	//	world space distance
	
	for ( int s=0;	s<MaxSteps;	s++ )
	{
		vec3 Position = Ray.Pos + Ray.Dir * RayTraversed;
		float SceneDistance = DistanceToScene( Position, Ray.Dir );
		float HitDistance = SceneDistance;
		
		RayTraversed += max( HitDistance, MinStep );
		/*	iq version
		if( abs(HitDistance) < (0.0001*RayTraversed) )
		{ 
			return vec4(Position,1);
		}
		*/
		if ( HitDistance < CloseEnough )
			return vec4(Position,1);
		
		//	ray gone too far
		if (RayTraversed >= MaxDistance)
			return vec4(Position,0);
	}

	//	ray never got close enough
	return vec4(0,0,0,-1);
}


float RayMarchSceneOcclusion(TRay Ray)
{
	const float MinDistance = 0.01;
	const float CloseEnough = MinDistance;
	const float MinStep = MinDistance;
	//const float MaxDistance = FAR_Z_EPSILON;
	const int MaxSteps = MAX_STEPS;
	
	float MaxDistance = length(Ray.Dir);
	Ray.Dir = normalize(Ray.Dir);
	
	float Occlusion = 0.0;
	float RayTraversed = 0.0;	//	world space distance
	
	//	this must be relative to ShadowHardness
	//	reverse the func
	float MaxDistanceForShadow = ShadowHardness * 1.1;
	
	for ( int s=0;	s<MaxSteps;	s++ )
	{
		vec3 Position = Ray.Pos + Ray.Dir * RayTraversed;
		float SceneDistance = DistanceToScene( Position, Ray.Dir );
		float HitDistance = SceneDistance;

		
		RayTraversed += max( HitDistance, MinStep );

		if ( HitDistance < MaxDistanceForShadow )
		{
			//	accumulate occlusion as we go
			//	the further down the ray, the more we accumualate the near misses
			float Bounce = 1.0 - clamp( ShadowHardness * HitDistance / RayTraversed,0.0,1.0);
			Occlusion = max( Occlusion, Bounce );
		}	

		
		if ( HitDistance < CloseEnough )
		{
			Occlusion = 1.0;
			break;
		}
		
		//	ray gone too far, never hit anything
		if (RayTraversed >= MaxDistance)
		{
			//Occlusion = 0.0;
			break;
		}
		
		if ( Occlusion >= 1.0 )
			break;
	}
	
	Occlusion = clamp( Occlusion, 0.0, 1.0 );
	return Occlusion*Occlusion*(3.0-2.0*Occlusion);
}

float MapDistance(vec3 Position)
{
	vec3 Dir = vec3(0,1,0);
	return DistanceToScene( Position, Dir );
}

vec3 calcNormal(vec3 pos)
{
	//return WorldUp;
	vec2 e = vec2(1.0,-1.0)*0.5773;
	const float eps = 0.0005;
	return normalize( e.xyy * MapDistance( pos + e.xyy*eps ) + 
					 e.yyx * MapDistance( pos + e.yyx*eps ) + 
					 e.yxy * MapDistance( pos + e.yxy*eps ) + 
					 e.xxx * MapDistance( pos + e.xxx*eps ) );
}



void main()
{
	TRay Ray;
	GetWorldRay(Ray.Pos,Ray.Dir);
	vec4 Colour = vec4(BackgroundColour,0.0);
	
	vec4 HitPos_Valid = RayMarchScene(Ray);
	
	if ( HitPos_Valid.w > 0.0 )
	{
		vec3 HitPos = HitPos_Valid.xyz;
		vec3 Normal = calcNormal(HitPos);
		float StepAwayFromSurface = BounceSurfaceDistance;
		
		Colour = vec4( HitPos, 1.0 );
		Colour = vec4( abs(HitPos), 1.0 );
		//Colour = vec4(1);
		Colour = vec4( abs(Normal),1.0);
		
		bool ApplyHardOcclusion = true;
		float ShadowMult = 0.0;	//	shadow colour
		
		if ( ApplyHardOcclusion )
		{
			TRay OcclusionRay;
			OcclusionRay.Pos = HitPos+Normal*StepAwayFromSurface;
			OcclusionRay.Dir = WorldLightPosition - HitPos;
			float Occlusion = RayMarchSceneOcclusion( OcclusionRay );
			Colour.xyz = mix( Colour.xyz, vec3(ShadowMult), Occlusion );
			//Colour.xyz = normalize(OcclusionRay.Dir);
		}
	}
	
	//	render gizmos
	int Gizmo = GetGizmo( Ray, HitPos_Valid );
	Colour.xyz = ApplyGizmoColour(Gizmo,Colour.xyz);
	
	
	//	vignette
	float Vignette = pow( 16.0*uv.x*uv.y*(1.0-uv.x)*(1.0-uv.y), VignettePow );
	Colour.xyz *= Vignette;
	
	gl_FragColor = vec4(Colour.xyz,1.0);

}

