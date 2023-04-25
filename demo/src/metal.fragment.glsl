/** World view */
uniform mat4 worldView;
/** World matrix */
uniform mat4 world;
/** View Matrix */
uniform mat4 view;
/** Camera position */
uniform vec3 cameraPosition;
/** environment cubemap */
uniform samplerCube envMaps[6];
/** map containing surface texture */
uniform sampler2D surfaceMaps[8];
/** map containing normal map + w as depth adjustment */
uniform sampler2D normalMap;
/** map containing physical effect on pixel shininess, refraction, emission */
uniform sampler2D physicalMap;

// uniform sampler2D grainMap;
/** inverse view matrix precomputed */
uniform mat4 invView;
/** we want to use normal map */
uniform int useNormal;
/** the diffus color of the component */
uniform vec4 diffusColor;
/** the ambiant color of the component */
uniform vec4 ambientColor;
uniform float amplification;
uniform float flatShininess;
uniform float scratchVisibility;

uniform mat4 localAnomalies[100];
uniform mat4 surfaceTreatments[100];
uniform int anomalyInstances;
uniform int treatmentInstances;

varying vec3 reflectedVector;
varying vec4 vPosition;
varying vec3 vNormal;
flat in float fHashColor;
// varying vec4 vTangent;
// varying vec3 vBitangent;
varying vec2 vUv;
varying vec3 posEye;
varying mat3 vTBN;

#define M_PI 3.1415926535897932384626433832795

#define SCRATCH 1
#define MARK 2
#define DEFORMATION 3
#define STAIN 4
#define TREATMENT 5

/**
 * L'espace world est l'espace 3d absolu de la scène entière, la matrice world
 * permet de passer de l'espace du mesh à l'espace world L'espace view est
 * l'espace dans le repère de la caméra, la matrice view permet de passer de
 * l'espace world à l'espace de la caméra
 */

/**
 * Projete le vecteur de la normalmap dans l'espace de la normal de la surface
 * pour obtenir la normal dans l'espace world
 */
vec3 perturbNormal(mat3 cotangentFrame, vec3 textureSample, float invert) {
  textureSample = textureSample * 2.0 - 1.0;

  // if (textureSample.z == 1.) {
  //   textureSample.x = 0.;
  //   textureSample.y = 0.;
  // }

  textureSample.x = textureSample.x * invert;
  textureSample.y = textureSample.y * invert;

  return cotangentFrame * textureSample;

  // return normalize(vec3(vec4(cotangentFrame * textureSample, 0.) * world));
}

/** Change depth of the normal with a factor */
vec3 adjustNorm(vec3 normal, float fac) {
  if (fac == 1.)
    return normal;
  vec3 v1 = (normal - 0.5) * 2.;
  v1.r = asin(v1.r);
  v1.g = asin(v1.g);
  v1.b = acos(v1.b);
  v1 *= fac;
  v1.r = sin(v1.r);
  v1.g = sin(v1.g);
  v1.b = cos(v1.b);
  // normalize to the 1 unit length
  v1 /= length(v1);

  return v1 / 2. + 0.5;
}

vec3 rotateNorm(vec3 normal, float cosAngle, float sinAngle) {
  if (cosAngle == 1. || normal.z == 1.)
    return normal;
  vec3 v1 = (normal - 0.5) * 2.;
  v1 = vec3(v1.x * cosAngle - v1.y * (-sinAngle),
            v1.x * (-sinAngle) + v1.y * cosAngle, v1.z);
  return v1 / 2. + 0.5;
}

// from http://www.java-gaming.org/index.php?topic=35123.0
vec4 cubic(float v) {
  vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
  vec4 s = n * n * n;
  float x = s.x;
  float y = s.y - 4.0 * s.x;
  float z = s.z - 4.0 * s.y + 6.0 * s.x;
  float w = 6.0 - x - y - z;
  return vec4(x, y, z, w) * (1.0 / 6.0);
}

vec4 textureBicubic(sampler2D sampler, vec2 texCoords) {

  vec2 texSize = vec2(textureSize(sampler, 0));
  vec2 invTexSize = 1.0 / texSize;

  texCoords = texCoords * texSize - 0.5;

  vec2 fxy = fract(texCoords);
  texCoords -= fxy;

  vec4 xcubic = cubic(fxy.x);
  vec4 ycubic = cubic(fxy.y);

  vec4 c = texCoords.xxyy + vec2(-0.5, +1.5).xyxy;

  vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
  vec4 offset = c + vec4(xcubic.yw, ycubic.yw) / s;

  offset *= invTexSize.xxyy;

  vec4 sample0 = texture(sampler, offset.xz);
  vec4 sample1 = texture(sampler, offset.yz);
  vec4 sample2 = texture(sampler, offset.xw);
  vec4 sample3 = texture(sampler, offset.yw);

  float sx = s.x / (s.x + s.y);
  float sy = s.z / (s.z + s.w);

  return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

vec4 getSurfaceMapPixel(highp int i, vec2 uv) {
  vec4 result;
  if (i < 0) {
    return vec4(0.5, 0.5, 1., 0.);
  } else if (i == 0) {
    result = textureBicubic(surfaceMaps[0], uv);
  } else if (i == 1) {
    result = textureBicubic(surfaceMaps[1], uv);
  } else if (i == 2) {
    result = textureBicubic(surfaceMaps[2], uv);
  } else if (i == 3) {
    result = textureBicubic(surfaceMaps[3], uv);
  } else if (i == 4) {
    result = textureBicubic(surfaceMaps[4], uv);
  } else if (i == 5) {
    result = textureBicubic(surfaceMaps[5], uv);
  }
  return result;
}

/**
 * Compute reflection of light on a surface
 * @param normal the normal vector
 * @param incidentEye position of the eye in the camera space
 * @param reverse 1 = normal is not changed, -1 = normal is reversed
 * @param shinness 0 = rough, 1 = mirror reflection
 */
vec4 normalToReflectColor(vec3 normal, vec3 incidentEye, float reverse,
                          float shininess, float depthFactor, float cosAngle,
                          float sinAngle) {
  /* normal dans l'espace world déviée par la texture normale */
  // vec3 vwNormal = vec3(world * vec4(perturbNormal(vTBN, normal.xyz,
  // reverse),0.));
  // vec3 vwNormal = perturbNormal(vTBN, normal.xyz, reverse);
  vec3 vwNormal = perturbNormal(
      vTBN, rotateNorm(adjustNorm(normal.xyz, depthFactor), cosAngle, sinAngle),
      reverse);

  /* position de la normal dans l'espace de la caméra */
  vec3 viewNormal = normalize(vec3(view * vec4(vwNormal, 0.0)));

  vec3 reflected;

  // reflected = vec3(invView * vec4(reflect(incidentEye, viewNormal), 0.0));

  // if (refractIndex != 1.) {
  //   reflected = vec3(invView * vec4(refract(reflect(incidentEye, viewNormal),
  //                                           -viewNormal, refractIndex * 2.),
  //                                   0.0));
  // } else {
  reflected = vec3(invView * vec4(reflect(incidentEye, viewNormal), 0.0));
  // }

  // vec2 longlat = vec2(atan(reflected.x, reflected.z), acos(-reflected.y));
  // vec2 reflecteduv = longlat / vec2(2.0 * M_PI, M_PI);
  // if (reflecteduv.x >= 1.0) reflecteduv.x = 0.99;
  // if (reflecteduv.y >= 1.0) reflecteduv.y = 0.99;

  vec4 t0 = vec4(0., 0., 0., 0.);
  vec4 t1 = vec4(0., 0., 0., 0.);
  // vec4 t2 = vec4(0., 0., 0., 0.);
  // vec4 t3 = vec4(0., 0., 0., 0.);

  shininess = 1. - shininess;

  highp int minId = int(floor(shininess * 5.));
  float coef = 0.;

  int n = 1;

  if (minId == 0) {
    t0 = textureCube(envMaps[0], reflected);
    t1 = textureCube(envMaps[1], reflected);
    coef = shininess * 5.;
  } else if (minId == 1) {
    t0 = textureCube(envMaps[1], reflected);
    t1 = textureCube(envMaps[2], reflected);
    coef = (shininess - 0.2) * 5.;
  } else if (minId == 2) {
    t0 = textureCube(envMaps[2], reflected);
    t1 = textureCube(envMaps[3], reflected);
    coef = (shininess - 0.4) * 5.;
  } else if (minId == 3) {
    t0 = textureCube(envMaps[3], reflected);
    t1 = textureCube(envMaps[4], reflected);
    coef = (shininess - 0.6) * 5.;
  } else if (minId == 4) {
    t0 = textureCube(envMaps[4], reflected);
    t1 = textureCube(envMaps[5], reflected);
    coef = (shininess - 0.8) * 5.;
  } else if (minId == 5) {
    t0 = textureCube(envMaps[4], reflected);
    t1 = textureCube(envMaps[5], reflected);
    coef = 1.;
  }

  vec4 color = mix(t0, t1, coef);
  return color;
}

vec2 transformUv(vec2 uv, float cosAngle, float sinAngle, float spriteU,
                 float spriteV, float destU, float destV, float spriteDensity,
                 float vExtraDensity) {
  uv = vec2((uv.x - destU) * spriteDensity, (uv.y - destV) * spriteDensity);
  uv = vec2((cosAngle * uv.x - sinAngle * uv.y) + spriteU,
            ((sinAngle * uv.x + cosAngle * uv.y) * vExtraDensity) + spriteV);
  return uv;
}

void main(void) {
  /* position de l'oeil dans l'espace de la camera */
  vec3 incidentEye = normalize(posEye);
  bool found = false;
  highp int type = 0;
  float depthFactor = 1.;
  vec2 surfUv = vUv;
  vec2 uv = vUv;
  float shininess = 1.;
  bool stain = false;
  bool carving = false;
  float cosAngle = 1.;
  float sinAngle = 0.;
  vec4 color = diffusColor;
  highp int textureIndex = 0;

  if (useNormal == 0) {
    gl_FragColor = vec4(1., 1., 1., 1.);
    return;
  }

  if (useNormal == 1) {

    /**
      localAnomalies[i][0][0] = spriteUv.x
      localAnomalies[i][0][1] = spriteUv.y
      localAnomalies[i][0][2] = cos Angle
      localAnomalies[i][0][3] = sin Angle
      localAnomalies[i][1][0] = half sprite width
      localAnomalies[i][1][1] = half sprite height
      localAnomalies[i][1][2] = destination u
      localAnomalies[i][1][3] = destination v
      localAnomalies[i][2][0] = sprite density
      localAnomalies[i][2][1] = extra density on v
      localAnomalies[i][2][2] = shininess
      localAnomalies[i][2][3] = anomaly type
      localAnomalies[i][3][0] = hashcode of the vertex color
      localAnomalies[i][3][1] = 0
      localAnomalies[i][3][2] = 0
      localAnomalies[i][3][3] = depth factor
    */
    for (int i = 0; i < anomalyInstances; i++) {
      if (fHashColor != localAnomalies[i][3][0])
        continue;

      /** optimisation */
      float dist = max(localAnomalies[i][1][0], localAnomalies[i][1][1]);
      if (abs(vUv.x - localAnomalies[i][1][2]) <
              dist / localAnomalies[i][2][0] &&
          abs(vUv.y - localAnomalies[i][1][3]) <
              dist / localAnomalies[i][2][0]) {
        // gl_FragColor = vec4(fHashColor / 10000000.);
        // return;

        type = int(round(localAnomalies[i][2][3]));
        depthFactor = localAnomalies[i][3][3];
        uv = transformUv(vUv, localAnomalies[i][0][2], localAnomalies[i][0][3],
                         localAnomalies[i][0][0], localAnomalies[i][0][1],
                         localAnomalies[i][1][2], localAnomalies[i][1][3],
                         localAnomalies[i][2][0], localAnomalies[i][2][1]);

        if (uv.x >= localAnomalies[i][0][0] - localAnomalies[i][1][0] + 0.003 &&
            uv.y >= localAnomalies[i][0][1] - localAnomalies[i][1][1] + 0.003 &&
            uv.x <= localAnomalies[i][0][0] + localAnomalies[i][1][0] - 0.003 &&
            uv.y <= localAnomalies[i][0][1] + localAnomalies[i][1][1] - 0.003) {
          // gl_FragColor = vec4(1., 1., 1., 1.);
          // return;
          found = true;
          cosAngle = localAnomalies[i][0][2];
          sinAngle = localAnomalies[i][0][3];
          shininess = localAnomalies[i][2][2];
          if (type == STAIN && texture2D(physicalMap, uv).y < 1.) {
            stain = true;
            break;
          } else if (type != STAIN && texture2D(normalMap, uv).z != 1.) {
            carving = true;
            stain = false;
            break;
          } else {
            // shininess = 1.;
          }
        }
      }
    }

    /**
      surfaceTreatments[i][0][0] = color red
      surfaceTreatments[i][0][1] = 0
      surfaceTreatments[i][0][2] = translate.x
      surfaceTreatments[i][0][3] = translate.y
      surfaceTreatments[i][1][0] = color green
      surfaceTreatments[i][1][1] = hashcode of the vertex color
      surfaceTreatments[i][1][2] = 0
      surfaceTreatments[i][1][3] = 0
      surfaceTreatments[i][2][0] = color blue
      surfaceTreatments[i][2][1] = texture index
      surfaceTreatments[i][2][2] = shininess
      surfaceTreatments[i][2][3] = angle
      surfaceTreatments[i][3][0] = type
      surfaceTreatments[i][3][1] = 0
      surfaceTreatments[i][3][2] = scale
      surfaceTreatments[i][3][3] = depth factor
    */
    if (!carving) {
      bool surf = false;
      for (int i = 0; i < treatmentInstances; i++) {
        if (fHashColor != surfaceTreatments[i][1][1])
          continue;
        type = TREATMENT;
        // gl_FragColor = vec4(1., 1., 1., 1.);
        // return;
        shininess = surfaceTreatments[i][2][2];
        depthFactor = surfaceTreatments[i][3][3];
        float scale = surfaceTreatments[i][3][2];
        textureIndex = int(round(surfaceTreatments[i][2][1]));
        surfUv = vec2(mod(vUv.x * scale + surfaceTreatments[i][0][2], 1.),
                      mod(vUv.y * scale + surfaceTreatments[i][0][3], 1.));
        color = vec4(surfaceTreatments[i][0][0], surfaceTreatments[i][1][0],
                     surfaceTreatments[i][2][0], 1.);
        found = true;
        surf = true;
        break;
      }
      if (!surf && !carving && !stain) {
        found = false;
      }
    } else {
      for (int i = 0; i < treatmentInstances; i++) {
        if (fHashColor != surfaceTreatments[i][1][1])
          continue;
        color = vec4(surfaceTreatments[i][0][0], surfaceTreatments[i][1][0],
                     surfaceTreatments[i][2][0], 1.);
      }
    }
  }

  /* couleur du reflet plat */

  vec4 finalReflectColor;
  /** if the surface has normal map then read the texture and apply effect */
  if (useNormal == 1 && found) {
    /* normal of given pixel on the surface, x,y,z are normal vector
       coordinates, w is used to indicate the depth of the scratch 0 is carving,
       1 is light scratch
        if w is close to 1 only the flat surface reflection is send, the scratch
       doesn't play with light too much and fade */
    vec4 normalFragment = type == TREATMENT
                              ? getSurfaceMapPixel(textureIndex, surfUv)
                              : texture2D(normalMap, uv);

    /* secondary texture used for brush texture attributes : x is a coefficient
     * to compute brush depth, local shininess : y, anomaly type : z, local
     * ambient: w */
    /* depends on type of anomaly */
    vec4 physicalFragment =
        type == TREATMENT ? vec4(1., 1., 0.2, 0.) : texture2D(physicalMap, uv);

    if (stain && type == TREATMENT) {
      vec4 physicalFragment = texture2D(physicalMap, uv);
      shininess = shininess * physicalFragment.y;
    }
    if (!stain && type == TREATMENT) {
      cosAngle = 1.;
      sinAngle = 0.;
    }

    // type = int(round(1. / physicalFragment.z));

    /** if the normal is not flat then it's either a brushed surface or a
     * scratched surfaced */
    if (((type == MARK || type == SCRATCH) && normalFragment.z < 1.) ||
        type == TREATMENT) {
      /* couleur du reflet droit */
      vec4 reflectColor;

      /** It's a mark then compute differently */
      if (type == MARK || type == TREATMENT) {
        finalReflectColor =
            normalToReflectColor(normalFragment.xyz, incidentEye, 1.,
                                 shininess * flatShininess * physicalFragment.y,
                                 depthFactor, cosAngle, sinAngle);
      } else

        /** Physical attribute is not 1 then it's a brushed texture pixel,
         * combine reflect color with flat color to define brushed metal
         * rendering, quite empirical */
        if (physicalFragment.x < 1.) {
          reflectColor =
              normalToReflectColor(normalFragment.xyz, incidentEye, 1., 0.,
                                   depthFactor, cosAngle, sinAngle) *
              scratchVisibility;
          finalReflectColor = reflectColor; // / 2. + invReflectColor / 2.;
          finalReflectColor =
              finalReflectColor * 0.5 + finalReflectColor * physicalFragment.x;
        } else {
          reflectColor = normalToReflectColor(
                             normalFragment.xyz, incidentEye, 1.,
                             shininess * flatShininess * physicalFragment.y,
                             depthFactor, cosAngle, sinAngle) *
                         scratchVisibility;
          /** normalFragment.w is the width of the scratch, 0 is carving, 1 is
           * very light scratch */
          // if (normalFragment.w > 0.9) {
          //   /* couleur du reflet inversé */
          //   vec4 invReflectColor =
          //       normalToReflectColor(normalFragment.xyz, incidentEye, -1.,
          //                            flatShininess * physicalFragment.y,
          //                            depthFactor) *
          //       scratchVisibility;
          //   finalReflectColor = reflectColor / 2. + invReflectColor / 2.;
          // } else {
          finalReflectColor = reflectColor;
          // }
          /** reflection on the surface as if it was flat, used to mix with ray
           * light reflexion and thus soften the reflection of a scratch */
          vec4 flatReflectColor = normalToReflectColor(
              vec3(0.5, 0.5, 1.), incidentEye, 1.,
              shininess * flatShininess * physicalFragment.y, 1., cosAngle,
              sinAngle);
          finalReflectColor =
              mix(flatReflectColor, finalReflectColor, (1. - normalFragment.w));
        }
    } else {
      /** reflection on the surface as if it was flat, used to mix with ray
       * light reflexion and thus soften the reflection of a scratch */
      vec4 flatReflectColor =
          normalToReflectColor(vec3(0.5, 0.5, 1.), incidentEye, 1.,
                               shininess * flatShininess * physicalFragment.y,
                               1., cosAngle, sinAngle);
      /** Else it's a flat surface then use the flat reflect color */
      finalReflectColor = flatReflectColor;
    }

    vec4 diff = color;

    if (stain) {
      vec4 normalFragment = texture2D(normalMap, uv);
      vec4 physicalFragment = texture2D(physicalMap, uv);
      diff = mix(vec4(normalFragment.rgb, 1.), diff, physicalFragment.y);
    }

    /** Compute the final color with diffuse, amplication and ambient color */
    gl_FragColor = mix(finalReflectColor * diff * amplification + ambientColor,
                       diff, physicalFragment.w);
  } else {
    /** else render a basic metal reflection */
    vec4 flatReflectColor =
        normalToReflectColor(vec3(0.5, 0.5, 1.), incidentEye, 1., flatShininess,
                             1., cosAngle, sinAngle);
    /** Compute the final color with diffuse, amplication and ambient color */
    gl_FragColor =
        flatReflectColor * diffusColor * amplification + ambientColor;
  }
}