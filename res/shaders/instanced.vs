#version 330 core

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;

layout (location = 12) in mat4 instance;

// Input uniform values
uniform mat4 mvp;
uniform mat4 projection;
uniform mat4 view;
uniform float[1000] yOffset;

// Output vertex attributes (to fragment shader)
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 fragNormal;

// NOTE: Add here your custom variables

void main()
{
    // Send vertex attributes to fragment shader
    fragTexCoord = vertexTexCoord;
    fragTexCoord.y -= yOffset[gl_InstanceID];
    
    // Calculate final vertex position
    mat4 mvpi = mvp * instance;
    gl_Position = mvpi * vec4(vertexPosition, 1.0);
}
