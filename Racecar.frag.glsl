precision highp float;
varying vec3 WorldPosition;
varying vec4 OutputProjectionPosition;
uniform mat4 CameraToWorldTransform;
uniform vec3 WorldLightPosition;
#define FloorY	0.0
#define WallZ	2.0
#define FarZ	20.0
#define WorldUp	vec3(0,1,0)
#define WorldForward	vec3(0,0,1)	

uniform float TimeNormal;
uniform bool UserHoverHandle;
uniform vec2 MouseUv;

#define Mat_None	0.0
#define Mat_Floor	1.0
#define Mat_Toaster	2.0
#define Mat_Handle	3.0
#define Mat_Bread	4.0
#define Mat_Red		5.0
#define Mat_Blue	6.0
#define dm_t	vec2	//	distance material
#define dmh_t	vec3	//	distance material heat

uniform vec4 RenderTargetRect;

uniform vec3 ToasterSize;
#define HoleSize	vec3( ToasterSize.x * 0.9, 1.0, 0.06 )
#define ToastSize	vec3( 0.16, 0.15, 0.03 )
#define ToasterPos	vec3(0,0,0)//vec3(0,-0.20,0)
#define ShadowMult	0.2

uniform vec3 HandleTop;
uniform vec3 HandleBottom;
uniform float HandleTime;
uniform float ToastPositionTime;
uniform vec3 HandleSize;

#define CAR_COUNT	2
uniform vec3 CarPositions[CAR_COUNT];
uniform vec3 CarColours[CAR_COUNT];
uniform float CarAngles[CAR_COUNT];
#define CarSpecular	1.0
#define CarMaterial(c) (99.0+float(c))
#define CarAngle(c) CarAngles[c]

#define TRACK_POINT_COUNT	5
uniform vec2 TrackPoints[TRACK_POINT_COUNT];

#define MAX_STEPS	50

void GetMouseRay(out vec3 RayPos,out vec3 RayDir)
{
	float CameraViewportRatio = RenderTargetRect.w/RenderTargetRect.z;
	//	gr: need the viewport used in the matrix... can we extract it?
	float Halfw = (1.0/CameraViewportRatio)/2.0;
	float Halfh = 1.0 / 2.0;
	vec2 ViewportUv = mix( vec2(-Halfw,Halfh), vec2(Halfw,-Halfh), MouseUv);
	vec4 Near4 = CameraToWorldTransform * vec4(ViewportUv,0,1);
	vec4 Far4 = CameraToWorldTransform * vec4(ViewportUv,1,1);
	vec3 Near3 = Near4.xyz / Near4.w;
	vec3 Far3 = Far4.xyz / Far4.w;
	RayPos = Near3;
	RayDir = Far3 - Near3;
	RayDir = normalize(RayDir);
}

void GetWorldRay(out vec3 RayPos,out vec3 RayDir)
{
	//	ray goes from camera
	//	to WorldPosition, which is the triangle's surface pos
	vec4 CameraWorldPos4 = CameraToWorldTransform * vec4(0,0,0,1);
	vec3 CameraWorldPos3 = CameraWorldPos4.xyz / CameraWorldPos4.w;
	RayPos = CameraWorldPos3;
	RayDir = WorldPosition - RayPos;
	RayDir = normalize(RayDir);
}

float rand(vec3 co)
{
	return fract(sin(dot(co, vec3(12.9898, 78.233, 54.53))) * 43758.5453);
}

vec2 rotate(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, -s, s, c);
	return m * v;
}
float opUnion( float d1, float d2 ) { return min(d1,d2); }

float opSubtraction( float d1, float d2 ) { return max(-d1,d2); }

float opIntersection( float d1, float d2 ) { return max(d1,d2); }

float opSmoothUnion( float d1, float d2, float k ) {
	float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
	return mix( d2, d1, h ) - k*h*(1.0-h); }


float sdSphere(vec3 Position,vec4 Sphere)
{
	return length( Position-Sphere.xyz )-Sphere.w;
}
float sdBox( vec3 p, vec3 c, vec3 b )
{
	p = p-c;
	vec3 q = abs(p) - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}
float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
	vec3 pa = p - a, ba = b - a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return length( pa - ba*h ) - r;
}

float sdCappedCylinder( vec3 p, float h, float r )
{
	vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(h,r);
	return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdPlane( vec3 p, vec3 n, float h )
{
	// n must be normalized
	return dot(p,n) + h;
}



vec2 sdFloor(vec3 Position,vec3 Direction)
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
	return vec2(d,tp1);
}

float sdMouseRay(vec3 Position)
{
	vec3 MousePos,MouseDir;
	GetMouseRay( MousePos, MouseDir );
	return sdCapsule( Position, MousePos, MousePos+MouseDir*1.0, 0.01 );
}


dm_t Closest(dm_t a,dm_t b)
{
	return a.x < b.x ? a : b;
}


dm_t sdCar(vec3 Position,vec3 CarPosition,float CarAngle,float CarMaterial)
{
	//	move to car localspace
	//	inverse transform
	Position -= CarPosition;
	Position.xz = rotate(Position.xz, -radians(CarAngle));
	Position += CarPosition;
	
	float ChasisHeight = 0.04;
	vec3 BottomSize = vec3( 0.1, 0.02, 0.3 );
	vec3 TopSize = vec3( BottomSize.x, 0.04, 0.1 );
	vec3 BottomOffset = vec3(0,BottomSize.y+ChasisHeight,0);
	vec3 TopOffset = BottomOffset + vec3(0,TopSize.y,0);
	float EdgeRadius = 0.03;
	
	float Bottom = sdBox( Position, CarPosition+BottomOffset, BottomSize/2.0 );
	Bottom -= EdgeRadius;
	float Top = sdBox( Position, CarPosition+TopOffset, TopSize/2.0 );
	Top -= EdgeRadius;
	
	float Smooth = 0.04;
	float Distance = opSmoothUnion( Bottom, Top, Smooth );
	dm_t Body = dm_t( Distance, CarMaterial );
	
	return Body;
}


dm_t Map(vec3 Position,vec3 Dir)
{
	dm_t d = dm_t(999.0,Mat_None);
	//d = Closest( d, sdSphere( Position, vec4(0,0,0,0.10) );
	
	//d = Closest( d, dm_t( sdMouseRay(Position), Mat_Red ) );
	d = Closest( d, dm_t( sdFloor(Position,Dir).x, Mat_Floor ) );
	for ( int c=0;	c<CAR_COUNT;	c++ )
		d = Closest( d, sdCar( Position, CarPositions[c], CarAngle(c), CarMaterial(c) ) );
	return d;
}

float MapDistance(vec3 Position)
{
	vec3 Dir = vec3(0,0,0);
	return Map( Position, Dir ).x;
}

vec3 calcNormal(vec3 pos)
{
	vec2 e = vec2(1.0,-1.0)*0.5773;
	const float eps = 0.0005;
	vec3 Dir = vec3(0,0,0);
	return normalize( e.xyy * MapDistance( pos + e.xyy*eps ) + 
					 e.yyx * MapDistance( pos + e.yyx*eps ) + 
					 e.yxy * MapDistance( pos + e.yxy*eps ) + 
					 e.xxx * MapDistance( pos + e.xxx*eps ) );
}

dmh_t GetRayCastDistanceHeatMaterial(vec3 RayPos,vec3 RayDir)
{
	vec2 FloorTop = sdFloor(RayPos,RayDir);
	//float DidHitFloor = FloorTop.y;
	float DidHitFloor = 0.0;
	
	//	gr: for some reason, this I think is really small and we hit it straight away??
	//float MaxDistance = mix( FarZ, FloorTop.x, DidHitFloor );
	//
	float MaxDistance = FarZ;
	
	float RayDistance = 0.0;
	float HitMaterial = mix(Mat_None,Mat_Floor,DidHitFloor);	//	change to material later. 0 = miss
	float Heat = 0.0;
	
	for ( int s=0;	s<MAX_STEPS;	s++ )
	{
		Heat += 1.0/float(MAX_STEPS);
		vec3 StepPos = RayPos + (RayDir*RayDistance);
		dm_t StepDistanceMat = Map(StepPos,RayDir);
		RayDistance += StepDistanceMat.x;
		if ( RayDistance >= MaxDistance )
		{
			RayDistance = MaxDistance;
			HitMaterial = Mat_Red;
			break;
		}
		if ( StepDistanceMat.x < 0.001 )
		{
			HitMaterial = StepDistanceMat.y;
			break;
		}
	}
	return dmh_t( RayDistance, HitMaterial, Heat );
}

float ZeroOrOne(float f)
{
	//	or max(1.0,floor(f+0.0001)) ?
	//return max( 1.0, f*10000.0);
	return (f ==0.0) ? 0.0 : 1.0; 
}

vec3 GetNormalColour(vec3 Normal)
{
	Normal += 1.0;
	Normal /= 2.0;
	return Normal;
}

float Range(float Min,float Max,float Value)
{
	return (Value-Min) / (Max-Min);
}

/*
 vec3 GetLitColour(vec3 Position,vec3 Normal,vec3 Colour,float Shiny)
 {
 float Dot = abs( dot( Normal, normalize(WorldLightPosition-Position) ) );
 Dot = mix( 0.5, 1.0, Dot );
 Dot *= Dot;
 //Dot = 1.0 - Dot;	Dot *= Dot;	Dot=1.0-Dot; 
 
 Shiny *= 0.15;
 if ( Dot > 1.0-Shiny )
 return mix( Colour, vec3(1,1,1), Range(1.0-Shiny, 1.0, Dot ) );
 Colour *= Dot;
 return Colour;
 }
 */
vec4 GetLitColour(vec3 WorldPosition,vec3 Normal,vec3 SeedColour,float Specular)
{
	vec3 RumBright = SeedColour;//	rum
	//vec3 RumMidTone = vec3(181, 81, 4)/vec3(255,255,255);//	rum
	vec3 RumMidTone = RumBright * vec3(0.7,0.5,0.1);//vec3(181, 81, 4)/vec3(255,255,255);//	rum
	
	vec3 Colour = RumMidTone;
	
	vec3 DirToLight = normalize( WorldLightPosition-WorldPosition );
	float Dot = max(0.0,dot( DirToLight, Normal ));
	
	Colour = mix( Colour, RumBright, Dot );
	
	//	specular
	float DotMax = mix( 1.0, 0.96, Specular ); 
	if ( Dot > DotMax )
		Colour = vec3(1,1,1);
	
	return vec4( Colour, 1.0 );
}


#define PinkColour		vec3(1,0,1)
#define FloorWhite		(vec3(171, 205, 237)/255.0)
#define FloorBlue		(vec3(87, 139, 189)/255.0)
#define ToasterColour	(vec3(235, 64, 52)/255.0)
//#define ToasterColour	(vec3(245, 240, 215)/255.0)
//#define ToasterColour	(vec3(50, 168, 168)/255.0)

#define HandleColour	vec3(0.3,0.3,0.3)
#define BreadStartColour	vec3(0.98, 0.88, 0.72 )
#define BreadMidColour		(vec3(204, 131, 35)/255.0)
#define BreadEndColour		vec3(0.30, 0.30, 0.30 )
#define BreadSpecular	0.0
#define ToasterSpecular	1.0
uniform float Cook;


// Test if point p crosses line (a, b), returns sign of result
float testCross(vec2 a, vec2 b, vec2 p)
{
	return sign((b.y-a.y) * (p.x-a.x) - (b.x-a.x) * (p.y-a.y));
}

// Determine which side we're on (using barycentric parameterization)
float signBezier(vec2 A, vec2 B, vec2 C, vec2 p)
{ 
	vec2 a = C - A, b = B - A, c = p - A;
	vec2 bary = vec2(c.x*b.y-b.x*c.y,a.x*c.y-c.x*a.y) / (a.x*b.y-b.x*a.y);
	vec2 d = vec2(bary.y * 0.5, 0.0) + 1.0 - bary.x - bary.y;
	return mix(sign(d.x * d.x - d.y), mix(-1.0, 1.0, 
										  step(testCross(A, B, p) * testCross(B, C, p), 0.0)),
			   step((d.x - d.y), 0.0)) * testCross(A, C, B);
}

// Solve cubic equation for roots
vec3 solveCubic(float a, float b, float c)
{
	float p = b - a*a / 3.0, p3 = p*p*p;
	float q = a * (2.0*a*a - 9.0*b) / 27.0 + c;
	float d = q*q + 4.0*p3 / 27.0;
	float offset = -a / 3.0;
	if(d >= 0.0) { 
		float z = sqrt(d);
		vec2 x = (vec2(z, -z) - q) / 2.0;
		vec2 uv = sign(x)*pow(abs(x), vec2(1.0/3.0));
		return vec3(offset + uv.x + uv.y);
	}
	float v = acos(-sqrt(-27.0 / p3) * q / 2.0) / 3.0;
	float m = cos(v), n = sin(v)*1.732050808;
	return vec3(m + m, -n - m, n - m) * sqrt(-p / 3.0) + offset;
}

// Find the signed distance from a point to a bezier curve
float sdBezier(vec2 A, vec2 B, vec2 C, vec2 p)
{    
	B = mix(B + vec2(1e-4), B, abs(sign(B * 2.0 - A - C)));
	vec2 a = B - A, b = A - B * 2.0 + C, c = a * 2.0, d = A - p;
	vec3 k = vec3(3.*dot(a,b),2.*dot(a,a)+dot(d,b),dot(d,a)) / dot(b,b);      
	vec3 t = clamp(solveCubic(k.x, k.y, k.z), 0.0, 1.0);
	vec2 pos = A + (c + b*t.x)*t.x;
	float dis = length(pos - p);
	pos = A + (c + b*t.y)*t.y;
	dis = min(dis, length(pos - p));
	pos = A + (c + b*t.z)*t.z;
	dis = min(dis, length(pos - p));
	return dis * signBezier(A, B, C, p);
}

#define TrackWidth	0.4
#define CheckpointWidth	0.1

float GetTrackPointDistance(vec2 FloorPosition,vec2 Prev,vec2 This,vec2 Next)
{
	//	https://www.shadertoy.com/view/ltXSDB
	//	gr: change mid point so it goes through
	This = (4.0 * This - Prev - Next) / 2.0;
	float BezierDistance = sdBezier( Prev, This, Next, FloorPosition );
	
	//	sign of this distance is left or right
	float Sign = (BezierDistance < 0.0) ? -1.0 : 1.0;
	BezierDistance = abs(BezierDistance) - TrackWidth;
	
	return BezierDistance;
}


float GetTrackDistance(vec2 FloorPosition)
{
	float Distance = 9999.0;
	
	//	bezier curves dont follow	
	for ( int tp=0;	tp<TRACK_POINT_COUNT-2;	tp+=1 )
	{
		float d = GetTrackPointDistance( FloorPosition, TrackPoints[tp+0], TrackPoints[tp+1], TrackPoints[tp+2] );
		Distance = min(d,Distance);
	}
	float e = GetTrackPointDistance( FloorPosition, TrackPoints[TRACK_POINT_COUNT-2], TrackPoints[TRACK_POINT_COUNT-1], TrackPoints[0] );
	float f = GetTrackPointDistance( FloorPosition, TrackPoints[TRACK_POINT_COUNT-1], TrackPoints[0], TrackPoints[1] );
	Distance = min(e,Distance);
	Distance = min(f,Distance);
	
	return Distance;// - TrackWidth;
}


float GetCheckpointDistance(vec2 FloorPosition)
{
	float Distance = 9999.0;
	
	//	bezier curves dont follow	
	for ( int tp=0;	tp<TRACK_POINT_COUNT;	tp++ )
	{
		float d = length( FloorPosition - TrackPoints[tp+0] );
		d -= CheckpointWidth;
		Distance = min(d,Distance);
	}
	return Distance;
}

vec4 GetTrackColour(vec2 FloorPosition)
{
	float Noise = rand( floor(FloorPosition.xyy*200.0) );
	float MaxDistance = Noise * 0.41;
	
	float TrackDistance = GetTrackDistance(FloorPosition);
	float Alpha = 1.0 - (max(0.0,TrackDistance) / MaxDistance);
	if ( TrackDistance > MaxDistance )
		return vec4(0,0,0,0);
	
#define CheckpointColour	vec3(0.5,0,0)
	float CheckpointDistance = GetCheckpointDistance(FloorPosition);
	if ( CheckpointDistance <= 0.0 )
		return vec4( CheckpointColour, 0.5 );
	
#define TrackGreyA 0.25
#define TrackGreyB 0.15
	float Colour = mix( TrackGreyA, TrackGreyB, Noise );
	
	return vec4(Colour,Colour,Colour,Alpha*0.9);
}



vec3 GetFloorColour(vec3 WorldPosition,vec3 WorldNormal)
{
	float CheqSize = 0.5;
	vec2 Chequer = rotate( WorldPosition.xz, 0.6);
	//vec2 Chequer = rotate( WorldPosition.xy, 0.4);
	Chequer = mod( Chequer, CheqSize ) / CheqSize;
	bool x = Chequer.x < 0.5;
	bool y = Chequer.y < 0.5;
	vec3 Colour = (x==y) ? FloorBlue : FloorWhite;
	//return GetLitColour(WorldPosition,WorldNormal,Colour,0.0);
	
	vec4 TrackColour = GetTrackColour(WorldPosition.xz);
	Colour = mix( Colour, TrackColour.xyz, TrackColour.w );
	
	//float DistanceToMouse = sdMouseRay(WorldPosition);
	//if ( DistanceToMouse <= 0.9 )
	//	Colour = PinkColour;
	
	return Colour;	
}

vec4 GetToasterColour(vec3 WorldPos,vec3 WorldNormal)
{
	vec3 Colour = ToasterColour;
	float DistanceToMouse = sdMouseRay(WorldPos);
	DistanceToMouse = 999.0;
	if ( DistanceToMouse <= 0.1 )
		Colour = PinkColour;
	
	return GetLitColour(WorldPos,WorldNormal,Colour,ToasterSpecular);
}

vec4 GetBreadColour(vec3 WorldPos,vec3 WorldNormal)
{
	vec3 Colour = BreadStartColour;
	//	get a curve between colours
	float CookMid = 0.7;
	
	if ( Cook < CookMid )
	{
		float t = Range(0.0,CookMid,Cook);
		Colour = mix( BreadStartColour, BreadMidColour, t );
	}
	else
	{
		float t = Range(CookMid,1.0,Cook);
		Colour = mix( BreadMidColour, BreadEndColour, t );
	}
	
	return GetLitColour(WorldPos,WorldNormal,Colour,BreadSpecular);
}


vec4 GetMaterialColour(float Material,vec3 WorldPos,vec3 WorldNormal)
{
	if ( Material == Mat_Floor )	return vec4(GetFloorColour(WorldPos,WorldNormal),1.0);
	if ( Material == Mat_Toaster )	return GetToasterColour(WorldPos,WorldNormal);
	if ( Material == Mat_Bread )	return GetBreadColour(WorldPos,WorldNormal);
	if ( Material == Mat_Handle )	return GetLitColour(WorldPos,WorldNormal,HandleColour,ToasterSpecular);
	if ( Material == Mat_Red )		return vec4(1,0,0,1);
	if ( Material == Mat_Blue )		return vec4(0,0,1,1);
	if ( Material == Mat_None )		return vec4(0,0,0,0);
	
	for ( int c=0;	c<CAR_COUNT;	c++ )
		if ( Material == CarMaterial(c) )
			return GetLitColour(WorldPos,WorldNormal,CarColours[c],CarSpecular);
	
	//if ( !UserHoverHandle )
	//	if ( Material == Mat_Handle )	return GetLitColour(WorldPos,WorldNormal,ToasterColour,ToasterSpecular);
	
	return GetLitColour(WorldPos,WorldNormal,PinkColour,1.0);
}


float softshadow( in vec3 ro, in vec3 rd, float k )
{
	float res = 1.0;
	float ph = 1e20;
	float t = 0.0;
	for ( int i=0;	i<10;	i++ )
	{
		float h = MapDistance(ro + rd*t);
		if( h<0.001 )
			return 0.0;
		float y = h*h/(2.0*ph);
		float d = sqrt(h*h-y*y);
		res = min( res, k*d/max(0.0,t-y) );
		ph = h;
		t += h;
	}
	return res;
}


float HardShadow(vec3 Position,vec3 Direction)
{
	vec4 HitShadow = GetRayCastDistanceHeatMaterial( Position, Direction ).xzzy;
	return HitShadow.w > 0.0 ? 0.0 : 1.0;
	//	*= 0 if hit something
	//Colour.xyz *= mix( 1.0, ShadowMult, ZeroOrOne(HitShadow.w)*(1.0-HitShadow.y) );
	/*
	 //	shadow
	 vec4 HitShadow = GetRayCastDistanceHeatMaterial( HitPos+Normal*0.1, normalize(WorldLightPosition-HitPos) ).xzzy;
	 //	*= 0 if hit something
	 Colour.xyz *= mix( 1.0, ShadowMult, ZeroOrOne(HitShadow.w)*(1.0-HitShadow.y) );
	 */
}

//	output data at 0,0
vec2 GetScreenUv()
{
	//vec3 ndc = gl_Position.xyz / gl_Position.w;
	vec2 uv = OutputProjectionPosition.xy / OutputProjectionPosition.zz;
	//vec2 uv = OutputProjectionPosition.xy / OutputProjectionPosition.ww;
	//uv *= OutputProjectionPosition.ww;
	uv += 1.0;
	uv /= 2.0;
	return uv;
}

void main()
{
	vec3 RayPos,RayDir;
	GetWorldRay( RayPos, RayDir );
	vec4 HitDistance = GetRayCastDistanceHeatMaterial(RayPos,RayDir).xzzy;
	vec3 HitPos = RayPos + (RayDir*HitDistance.x); 
	
	
	
	vec3 Normal = calcNormal(HitPos);
	
	vec4 Colour = GetMaterialColour(HitDistance.w,HitPos,Normal);
	
	//Colour.xyz *= mix(1.0,0.7,HitDistance.y);	//	ao from heat
	
	
	float Shadowk = 1.70;
	vec3 ShadowRayPos = HitPos+Normal*0.0051;
	vec3 ShadowRayDir = normalize(WorldLightPosition-HitPos);
	float Shadow = softshadow( ShadowRayPos, ShadowRayDir, Shadowk );
	//float Shadow = softshadow( WorldLightPosition, -ShadowRayDir, Shadowk );
	//float Shadow = HardShadow( ShadowRayPos, ShadowRayDir );
	Colour.xyz *= mix( ShadowMult, 1.0, Shadow );//Shadow * ShadowMult;
	
	gl_FragColor = Colour;
	//if ( Colour.w == 0.0 )	discard;
}
