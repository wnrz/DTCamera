attribute float a_pID;
attribute float a_pRadiusOffset;
attribute float a_pVelocityOffset;
attribute float a_pDecayOffset;
attribute float a_pSizeOffset;
attribute vec3 a_pColorOffset;

uniform mat4 u_ProjectionMatrix;
uniform vec2 u_Gravity;
uniform float u_Time;
uniform float u_eRadius;
uniform float u_eVelocity;
uniform float u_eDecay;
uniform float u_eSizeStart;
uniform float u_eSizeEnd;
uniform vec2 u_ePosition;

varying vec3 v_pColorOffset;
varying float v_Growth;
varying float v_Decay;

void main(void)
{
    float x = cos(a_pID);
    float y = sin(a_pID);
    float r = u_eRadius * a_pRadiusOffset;
    
    float growth = r / (u_eVelocity + a_pVelocityOffset);
    float decay = u_eDecay + a_pDecayOffset;
    
    float s = 1.0;
    
    if(u_Time < growth)
    {
        float time = u_Time / growth;
        x = x * r * time;
        y = y * r * time;
        
        s = u_eSizeStart;
    }
    else
    {
        float time = (u_Time - growth) / decay;
        x = (x * r) + (u_Gravity.x * time);
        y = (y * r) + (u_Gravity.y * time);
        
        s = mix(u_eSizeStart, u_eSizeEnd, time);
    }
    
    vec2 position = vec2(x, y) + u_ePosition;
    gl_Position = u_ProjectionMatrix * vec4(position, 0.0, 1.0);
    gl_PointSize = max(0.0, (s + a_pSizeOffset));
    
    v_pColorOffset = a_pColorOffset;
    v_Growth = growth;
    v_Decay = decay;
}
