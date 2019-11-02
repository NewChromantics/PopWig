precision highp float;

in vec2 uv;
uniform mat4 ScreenToCameraTransform;
uniform mat4 CameraToWorldTransform;

uniform float TerrainHeightScalar;
uniform float PositionToHeightmapScale;
uniform sampler2D HeightmapTexture;
uniform sampler2D ColourTexture;
uniform bool SquareStep;
uniform bool DrawColour;
uniform bool DrawHeight;
uniform float BrightnessMult;

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

float GetTerrainHeight(float2 xz,out float2 uv)
{
	xz *= PositionToHeightmapScale;
	uv = xz;
	float Height = texture2D( HeightmapTexture, uv ).x;
	Height *= TerrainHeightScalar;
	return Height;

	float x = xz.x;
	float z = xz.y;
	float y = sin(x) * sin(z);
	y *= TerrainHeightScalar;
	return y;
}

float4 RayMarchHeightmap(vec3 ro,vec3 rd,out float resT,out float3 Intersection)
{
	const float mint = 0.501;
	const float maxt = 40.0;
	const int Steps = 600;
	float lh = 0.0;
	float ly = 0.0;
	
	for ( int s=0;	s<Steps;	s++ )
	{
		//const float dt = (maxt - mint) / Steps;
		float st = float(s)/float(Steps);
		float nextst = float(s+1)/float(Steps);
		if ( SquareStep )
		{
			st *= st;
			nextst *= nextst;
		}
		float dt = nextst - st;
		float t = mix( mint, maxt, st );
		
		vec3 p = ro + rd*t;
		float2 uv;
		float TerrainHeight = GetTerrainHeight( p.xz, uv );
		float h = TerrainHeight;
		if ( p.y < TerrainHeight )
		{
			resT = t - dt + dt*(lh-ly)/(p.y-ly-h+lh);
			t = resT;
			p = ro + rd*t;

			TerrainHeight = GetTerrainHeight( p.xz, uv );
			
			Intersection = p;
			
			float3 Rgb = float3(1,1,1);
			
			if ( DrawColour )
				Rgb = texture2D( ColourTexture, uv ).xyz;
			else
				Rgb = float3( 1.0-uv.x, uv.y, 1.0 );
			
			if ( DrawHeight )
			{
				float Brightness = TerrainHeight * (1.0 / TerrainHeightScalar);
				Rgb *= Brightness * BrightnessMult;
			}
			return float4( Rgb, 1 );
		}
		lh = h;
		ly = p.y;
	}
	return float4(0,0,0,0);
}

void main()
{
	TRay Ray = GetWorldRay();

	float3 Intersection;
	float t = 0.0;
	
	float4 HeightmapColour = RayMarchHeightmap( Ray.Pos, Ray.Dir, t, Intersection );
	float4 Colour = float4(0,0,0,1);
	
	Colour = mix( Colour, HeightmapColour, HeightmapColour.w );
	gl_FragColor = Colour;
}

