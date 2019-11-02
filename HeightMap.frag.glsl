precision highp float;

in vec2 uv;
uniform mat4 ScreenToCameraTransform;
uniform mat4 CameraToWorldTransform;

const float EdgeWidth = 0.05;
const float CenterRadius = 1.0;
const float RingSize = 0.25;
const float TerrainHeightScalar = 3.4;
const float PositionToHeightmapScale = 0.009;
uniform sampler2D HeightmapTexture;

struct TRay
{
	vec3 Pos;
	vec3 Dir;
};

vec3 ScreenToWorld(float2 uv,float z)
{
	float x = mix( -1.0, 1.0, uv.x );
	float y = mix( 1.0, -1.0, uv.y );
	vec4 ScreenPos4 = vec4( x, y, z, 1 );
	vec4 CameraPos4 = ScreenToCameraTransform * ScreenPos4;
	vec4 WorldPos4 = CameraToWorldTransform * CameraPos4;
	vec3 WorldPos = WorldPos4.xyz / WorldPos4.w;
	return WorldPos;
}

TRay GetWorldRay()
{
	float Near = 0.01;
	float Far = 1000.0;
	TRay Ray;
	Ray.Pos = ScreenToWorld( uv, Near );
	Ray.Dir = ScreenToWorld( uv, Far ) - Ray.Pos;
	
	//	gr: this is backwards!
	Ray.Dir = -normalize( Ray.Dir );
	return Ray;
}

vec3 GetRayPositionAtTime(TRay Ray,float Time)
{
	return Ray.Pos + ( Ray.Dir * Time );
}

bool GetSphereIntersection(TRay Ray,float4 Sphere,out vec3 IntersectionPos)
{
	vec3 SphereCenter = Sphere.xyz;
	float SphereRadius = Sphere.w;
	
	//	nearest point on line
	vec3 oc = Ray.Pos - SphereCenter;
	float a = dot(Ray.Dir, Ray.Dir);
	float b = dot(oc, Ray.Dir);
	float c = dot(oc, oc) - SphereRadius * SphereRadius;
	float discriminant = b*b - a*c;
	//	if discriminat is 0, it literally hits the edge (only one intesrection point as they're so close
	//	<0 then miss
	//	so anything over 0 has two intersection points
	if (discriminant > 0.0)
	{
		//	get enter & exit rays
		//	/a puts it into direction-normalised
		float EnterTime = (-b - sqrt(b*b-a*c)) /a;
		float ExitTime = (-b + sqrt(b*b-a*c)) /a;
		
		//	gr: these if()s check it's in our best-case limit, but this check should be outside
		float t_min = 0.001;
		float t_max = 10000.0;
		
		if (EnterTime < t_max && EnterTime > t_min)
		{
			IntersectionPos = GetRayPositionAtTime( Ray, EnterTime );
			return true;
		}
		
		if (ExitTime < t_max && ExitTime > t_min)
		{
			IntersectionPos = GetRayPositionAtTime( Ray, ExitTime );
			return true;
		}
	}
	return false;
}


bool GetPlaneIntersection(TRay Ray,float4 Plane,out vec3 IntersectionPos)
{
	//	https://gist.github.com/doxas/e9a3d006c7d19d2a0047
	float PlaneOffset = Plane.w;
	float3 PlaneNormal = Plane.xyz;
	float PlaneDistance = -PlaneOffset;
	float Denom = dot( Ray.Dir, PlaneNormal);
	float t = -(dot( Ray.Pos, PlaneNormal) + PlaneDistance) / Denom;
	
	//	wrong side, enable for 2 sided
	bool DoubleSided = false;

	float Min = 0.01;
	
	if ( t <= Min && !DoubleSided )
		return false;
	
	IntersectionPos = GetRayPositionAtTime( Ray, t );
	return true;
}


float4 GetFloorColour(float3 WorldPosition)
{
	bool x = fract( WorldPosition.x ) < EdgeWidth;
	bool y = true;
	bool z = fract( WorldPosition.z ) < EdgeWidth;
		
	float Alpha = (x || z) ? 1.0 : 0.0;
	
	float RingCount = 4.0;
	if ( length(WorldPosition) < CenterRadius )
		if ( fract(length(WorldPosition)*RingCount*2.0) < RingSize )
			Alpha = 1.0;
	
	return float4( Alpha,Alpha,Alpha,1.0 );
}


float GetTerrainHeight(float2 xz)
{
	xz *= PositionToHeightmapScale;
	
	float Height = texture2D( HeightmapTexture, xz ).x;
	Height *= TerrainHeightScalar;
	return Height;

	float x = xz.x;
	float z = xz.y;
	float y = sin(x) * sin(z);
	y *= TerrainHeightScalar;
	return y;
}

bool castRay(vec3 ro,vec3 rd,out float resT,out float3 Intersection)
{
	const float mint = 0.001;
	const float maxt = 50.0;
	const int Steps = 300;
	
	for ( int s=0;	s<Steps;	s++ )
	{
		//const float dt = (maxt - mint) / Steps;
		float st = float(s)/float(Steps);
		st *= st;
		float t = mix( mint, maxt, st );
		
		vec3 p = ro + rd*t;
		float TerrainHeight = GetTerrainHeight( p.xz );
		if ( p.y < TerrainHeight )
		{
			resT = t - 0.5/**dt*/;
			Intersection = p;
			return true;
		}
	}
	return false;
}

void main()
{
	TRay Ray = GetWorldRay();

	float3 Intersection;
	float t = 0.0;
	if ( castRay( Ray.Pos, Ray.Dir, t, Intersection ) )
	{
		Intersection.y *= 1.0 / TerrainHeightScalar;
		Intersection.y *= 2.2;
		
		gl_FragColor = float4( Intersection.yyy, 1 );
	}
	else
	{
		gl_FragColor = float4(0,0,0,1);
	}
	/*
	float4 Plane = float4(0,-0.1,0,0);
	vec3 PlaneIntersectionPos;
	float4 FloorColour = float4(0,0,0,1);
	if ( GetPlaneIntersection( Ray, Plane, PlaneIntersectionPos ) )
	{
		FloorColour = GetFloorColour( PlaneIntersectionPos );
	}

	gl_FragColor = FloorColour;
	*/
}

/*
in float3 WorldPosition;
in float3 Colour;
uniform float EdgeWidth = 0.05;
uniform float CenterRadius = 1.0;
uniform float RingSize = 0.25;

void main()
{
	bool x = fract( WorldPosition.x ) < EdgeWidth;
	bool y = true;
	bool z = fract( WorldPosition.z ) < EdgeWidth;
	
	float Alpha = (x || z) ? 1 : 0;

	float RingCount = 4;
	if ( length(WorldPosition) < CenterRadius )
		if ( fract(length(WorldPosition)*RingCount*2.0) < RingSize )
			Alpha = 1;
	
	if ( Alpha < 1 )
		discard;
	
	gl_FragColor = float4( 1,1,1, Alpha );
}
*/

