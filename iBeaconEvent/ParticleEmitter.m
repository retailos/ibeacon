//
//  ParticleEmitter.m
//  ParticleEmitterDemo
//
// Copyright (c) 2010 71Squared
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// The design and code for the ParticleEmitter were heavely influenced by the design and code
// used in Cocos2D for their particle system.

#import "ParticleEmitter.h"
#import "TBXML.h"
#import "TBXMLParticleAdditions.h"
#import "Texture2D.h"
#import "NSDataAdditions.h"

#pragma mark -
#pragma mark Private interface

@interface ParticleEmitter (Private)

// Adds a particle from the particle pool to the emitter
- (BOOL)addParticle;

// Initialises a particle ready for use
- (void)initParticle:(Particle*)particle;

// Parses the supplied XML particle configuration file
- (void)parseParticleConfig:(TBXML*)aConfig;

// Set up the arrays that are going to store our particles
- (void)setupArrays;

- (void)initParticle:(Particle*)particle atCGPathControlPoint:(CGPathControlPoint)controlPoint;

@end

#pragma mark -
#pragma mark Public implementation

@implementation ParticleEmitter

@synthesize gravity;
@synthesize sourcePosition;
@synthesize active;
@synthesize particleCount;
@synthesize duration;
@synthesize animationType;
@synthesize speed;
@synthesize speedVariance;
@synthesize particleLifespan;
@synthesize particleLifespanVariance;
@synthesize maxParticles;

- (void)dealloc {
	
	// Release the memory we are using for our vertex and particle arrays etc
	// If vertices or particles exist then free them
	if (vertices) 
		free(vertices);
	if (particles)
		free(particles);
	
	if(texture)
		[texture release];
    
    if (animationPath) {
        CGPathRelease(animationPath);
    }
	
	// Release the VBOs created
	glDeleteBuffers(1, &verticesID);

	[super dealloc];
}

- (id)initParticleEmitterWithFile:(NSString*)aFileName {
		self = [super init];
		if (self != nil) {
			
			// Create a TBXML instance that we can use to parse the config file
			TBXML *particleXML = [[TBXML alloc] initWithXMLFile:aFileName];
			
			// Parse the config file
			[self parseParticleConfig:particleXML];
			
			[self setupArrays];
						
			// Finished with the config file now so we can release it
			[particleXML release];
		}
		return self;
}

- (void) setAnimationPoint:(CGPoint)p {
    animationPoint = p;
}

static void extractPointsApplier(void* info, const CGPathElement* element)
{
	NSMutableArray* points = (NSMutableArray*) info;
    
    if (element->points && element->type != kCGPathElementCloseSubpath) {
        CGPoint p = *(element->points);
        [points addObject:[NSValue valueWithCGPoint:p]];
    }
}

- (void) setAnimationPath:(CGPathRef)path {
    if (animationPath) {
        CGPathRelease(animationPath);
    }
    if (controlPoints) {
        free(controlPoints);
    }
    
    animationPath = CGPathRetain(path);

    NSMutableArray* points = [NSMutableArray array];
	CGPathApply(animationPath, points, extractPointsApplier);
    
    totalControlPoints = [points count];
    if (totalControlPoints > 0) {
        controlPoints = calloc(totalControlPoints, sizeof(CGPathControlPoint));
        
        if (controlPoints == NULL) {
            NSLog(@"not enough memory to save cgpath information");
            return;
        } else {
            CGPoint prevPoint = CGPointMake(0.0, 0.0);
            float totalDistance = 0;
            
            for (int i = 0; i < totalControlPoints; i++) {
                CGPoint point = [[points objectAtIndex:i] CGPointValue];
                
                float thisDistance = 0.0f;
                if (i != 0) {
                    thisDistance = sqrtf(
                                         (point.x - prevPoint.x) * (point.x - prevPoint.x) 
                                         + (point.y - prevPoint.y) * (point.y - prevPoint.y)
                                         );
                }
                totalDistance += thisDistance;

                controlPoints[i] = (CGPathControlPoint) {point, prevPoint, totalDistance};
                
                prevPoint = point;
            }
            
            for (int i = 0; i < totalControlPoints; i++) {
                CGPathControlPoint p = controlPoints[i];
                
                if (i == 0 && totalControlPoints > 1) {
                    CGPathControlPoint nextP = controlPoints[1];
                    CGPoint prevP = CGPointMake(2.0 * p.point.x - nextP.point.x, 2.0 * p.point.y - nextP.point.y);
                    
                    controlPoints[0] = (CGPathControlPoint) {p.point, prevP, p.portionFinished / totalDistance};
                } else {
                    controlPoints[i] = (CGPathControlPoint) {p.point, p.previousPoint, p.portionFinished / totalDistance};
                }
            }
        }
    }
    
    /*for (int i = 0; i < 50; i++) {
        if (i == 20 ) {
            int bb = 1;
            bb++;
        }
        float p = (float) i / 50.0;
        CGPathControlPoint cp = [self getPointByFinishedPortion:p];
        NSLog(@"point[%d]: (%f, %f)", i, cp.point.x, cp.point.y);
    }*/
}

- (BOOL) readyToStart {
    return !active && particleCount == 0;
}

- (void) reactivate {
    active = YES;
    elapsedTime = 0;
    emitCounter = 0;
}

- (CGPathControlPoint) getPointByFinishedPortion: (float) portion {
    if (portion <= 0) {
        return controlPoints[0];
    } else if (portion >= 1) {
        return controlPoints[totalControlPoints - 1];
    } else {
        for (int i = 0; i < totalControlPoints; i++) {
            CGPathControlPoint cp = controlPoints[i];
            if (portion < cp.portionFinished) {
                CGPathControlPoint prevP = controlPoints[i - 1];
                float r = portion - prevP.portionFinished;
                
                float total = cp.portionFinished - prevP.portionFinished;
                r = r / total;
                
                float x = (cp.point.x - prevP.point.x) * r + prevP.point.x;
                float y = (cp.point.y - prevP.point.y) * r + prevP.point.y;
                
                return (CGPathControlPoint) {CGPointMake(x, y), prevP.point, 0.0};
            }
        }
        
        // should not happen
        return controlPoints[0];
    }
}

- (void)updateWithDelta:(GLfloat)aDelta {
	// If the emitter is active and the emission rate is greater than zero then emit
	// particles
	if(active && emissionRate) {
		float rate = 1.0f/emissionRate;
		emitCounter += aDelta;
		while(particleCount < maxParticles && emitCounter > rate) {
            [self addParticle];

			emitCounter -= rate;
		}

		elapsedTime += aDelta;
		if(duration != -1 && duration < elapsedTime)
			[self stopParticleEmitter];
	}
	
	// Reset the particle index before updating the particles in this emitter
	particleIndex = 0;
	
	// Loop through all the particles updating their location and color
	while(particleIndex < particleCount) {

		// Get the particle for the current particle index
		Particle *currentParticle = &particles[particleIndex];
        
        // FIX 1
        // Reduce the life span of the particle
        currentParticle->timeToLive -= aDelta;
		
		// If the current particle is alive then update it
		if(currentParticle->timeToLive > 0) {
			
			// If maxRadius is greater than 0 then the particles are going to spin otherwise
			// they are effected by speed and gravity
			if (emitterType == kParticleTypeRadial) {

                // FIX 2
                // Update the angle of the particle from the sourcePosition and the radius.  This is only
				// done of the particles are rotating
				currentParticle->angle += currentParticle->degreesPerSecond * aDelta;
				currentParticle->radius -= currentParticle->radiusDelta;
                
				Vector2f tmp;
                
                if (animationType == kAnimatePath) {
                    CGPathControlPoint cp = [self getPointByFinishedPortion:((float)particleIndex / (float) particleCount)];
                    
                    tmp.x = cp.point.x - cosf(currentParticle->angle) * currentParticle->radius;
                    tmp.y = cp.point.y - sinf(currentParticle->angle) * currentParticle->radius;
                } else {
                    tmp.x = sourcePosition.x - cosf(currentParticle->angle) * currentParticle->radius;
                    tmp.y = sourcePosition.y - sinf(currentParticle->angle) * currentParticle->radius;
                }
				currentParticle->position = tmp;

				if (currentParticle->radius < minRadius)
					currentParticle->timeToLive = 0;
			} else {
				Vector2f tmp, radial, tangential;
                
                //radial = Vector2fZero;
                Vector2f diff = Vector2fSub(currentParticle->startPos, Vector2fZero);
                
                currentParticle->position = Vector2fSub(currentParticle->position, diff);
                
                if (currentParticle->position.x || currentParticle->position.y)
                    radial = Vector2fNormalize(currentParticle->position);
                
                tangential.x = radial.x;
                tangential.y = radial.y;
                radial = Vector2fMultiply(radial, currentParticle->radialAcceleration);
                
                GLfloat newy = tangential.x;
                tangential.x = -tangential.y;
                tangential.y = newy;
                tangential = Vector2fMultiply(tangential, currentParticle->tangentialAcceleration);
                
				tmp = Vector2fAdd( Vector2fAdd(radial, tangential), gravity);
                tmp = Vector2fMultiply(tmp, aDelta);
				currentParticle->direction = Vector2fAdd(currentParticle->direction, tmp);
				tmp = Vector2fMultiply(currentParticle->direction, aDelta);
				currentParticle->position = Vector2fAdd(currentParticle->position, tmp);
                currentParticle->position = Vector2fAdd(currentParticle->position, diff);
			}
			
			// Update the particles color
			currentParticle->color.red += currentParticle->deltaColor.red;
			currentParticle->color.green += currentParticle->deltaColor.green;
			currentParticle->color.blue += currentParticle->deltaColor.blue;
			currentParticle->color.alpha += currentParticle->deltaColor.alpha;
			
			// Place the position of the current particle into the vertices array
			vertices[particleIndex].x = currentParticle->position.x;
			vertices[particleIndex].y = currentParticle->position.y;
			
			// Place the size of the current particle in the size array
			currentParticle->particleSize += currentParticle->particleSizeDelta;
			vertices[particleIndex].size = MAX(0, currentParticle->particleSize);

			// Place the color of the current particle into the color array
			vertices[particleIndex].color = currentParticle->color;

			// Update the particle counter
			particleIndex++;
		} else {

			// As the particle is not alive anymore replace it with the last active particle 
			// in the array and reduce the count of particles by one.  This causes all active particles
			// to be packed together at the start of the array so that a particle which has run out of
			// life will only drop into this clause once
			if(particleIndex != particleCount - 1)
				particles[particleIndex] = particles[particleCount - 1];
			particleCount--;
		}
	}
}

- (void)stopParticleEmitter {
	active = NO;
	elapsedTime = 0;
	emitCounter = 0;
}

- (void)renderParticles {

	// Disable the texture coord array so that texture information is not copied over when rendering
	// the point sprites.
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);

	// Bind to the verticesID VBO and popuate it with the necessary vertex & color informaiton
	glBindBuffer(GL_ARRAY_BUFFER, verticesID);
	glBufferData(GL_ARRAY_BUFFER, sizeof(PointSprite) * maxParticles, vertices, GL_DYNAMIC_DRAW);

	// Configure the vertex pointer which will use the currently bound VBO for its data
	glVertexPointer(2, GL_FLOAT, sizeof(PointSprite), 0);
	glColorPointer(4,GL_FLOAT,sizeof(PointSprite),(GLvoid*) (sizeof(GLfloat)*3));
	
	// Bind to the particles texture
	glBindTexture(GL_TEXTURE_2D, texture.name);
	
	// Enable the point size array
	glEnableClientState(GL_POINT_SIZE_ARRAY_OES);
	
	// Configure the point size pointer which will use the currently bound VBO.  PointSprite contains
	// both the location of the point as well as its size, so the config below tells the point size
	// pointer where in the currently bound VBO it can find the size for each point
	glPointSizePointerOES(GL_FLOAT,sizeof(PointSprite),(GLvoid*) (sizeof(GL_FLOAT)*2));
	
	// Change the blend function used if blendAdditive has been set

    // Set the blend function based on the configuration
    glBlendFunc(blendFuncSource, blendFuncDestination);
	
	// Enable and configure point sprites which we are going to use for our particles
	glEnable(GL_POINT_SPRITE_OES);
	glTexEnvi( GL_POINT_SPRITE_OES, GL_COORD_REPLACE_OES, GL_TRUE );

	// Now that all of the VBOs have been used to configure the vertices, pointer size and color
	// use glDrawArrays to draw the points
	glDrawArrays(GL_POINTS, 0, particleIndex);

	// Unbind the current VBO
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	
	// Disable the client states which have been used incase the next draw function does 
	// not need or use them
	glDisableClientState(GL_POINT_SIZE_ARRAY_OES);
	glDisable(GL_POINT_SPRITE_OES);
	
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	// Re-enable the texture coordinates as we use them elsewhere in the game and it is expected that
	// its on
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
}

@end

#pragma mark -
#pragma mark Private implementation

@implementation ParticleEmitter (Private)

- (BOOL)addParticle {
	
	// If we have already reached the maximum number of particles then do nothing
	if(particleCount == maxParticles)
		return NO;
	
	// Take the next particle out of the particle pool we have created and initialize it
	Particle *particle = &particles[particleCount];
    if (animationType == kAnimatePath) {
        [self initParticle:particle atCGPathControlPoint:[self getPointByFinishedPortion:((float)particleCount / (float)maxParticles)]];
    } else {
        if (animationType == kAnimatePoint) {
            self.sourcePosition = Vector2fMake(animationPoint.x, animationPoint.y);
        }
        [self initParticle:particle];
    }
	
	// Increment the particle count
	particleCount++;
	
	// Return YES to show that a particle has been created
	return YES;
}

- (float) calculateAngleByPoint:(CGPoint)p andPoint:(CGPoint)prevP {
    if (p.x == prevP.x) {
        if (prevP.y >= p.y) {
            return 90;
        } else {
            return 270;
        }
    } else {
        return 360 - (atanf((prevP.y - p.y) / (prevP.x - p.x)) * 180.0 / M_PI);
    }
}

- (void)initParticle:(Particle*)particle atCGPathControlPoint:(CGPathControlPoint)controlPoint {
	
    float degree = [self calculateAngleByPoint:controlPoint.point andPoint:controlPoint.previousPoint];

	// Init the position of the particle.  This is based on the source position of the particle emitter
	// plus a configured variance.  The RANDOM_MINUS_1_TO_1 macro allows the number to be both positive
	// and negative
	particle->position.x = controlPoint.point.x + sourcePositionVariance.x * RANDOM_MINUS_1_TO_1();
	particle->position.y = controlPoint.point.y + sourcePositionVariance.y * RANDOM_MINUS_1_TO_1();
    particle->startPos.x = controlPoint.point.x;
    particle->startPos.y = controlPoint.point.y;
	
	// Init the direction of the particle.  The newAngle is calculated using the angle passed in and the
	// angle variance.
	float newAngle = (GLfloat)DEGREES_TO_RADIANS(degree + angleVariance * RANDOM_MINUS_1_TO_1());
	
	// Create a new Vector2f using the newAngle
	Vector2f vector = Vector2fMake(cosf(newAngle), sinf(newAngle));
	
	// Calculate the vectorSpeed using the speed and speedVariance which has been passed in
	float vectorSpeed = speed + speedVariance * RANDOM_MINUS_1_TO_1();
	
	// The particles direction vector is calculated by taking the vector calculated above and
	// multiplying that by the speed
	particle->direction = Vector2fMultiply(vector, vectorSpeed);
	
	// Set the default diameter of the particle from the source position
	particle->radius = maxRadius + maxRadiusVariance * RANDOM_MINUS_1_TO_1();
	particle->radiusDelta = (maxRadius / particleLifespan) * (1.0 / MAXIMUM_UPDATE_RATE);
    
    particle->angle = DEGREES_TO_RADIANS(degree + angleVariance * RANDOM_MINUS_1_TO_1());
	//particle->angle = DEGREES_TO_RADIANS(angle + angleVariance * RANDOM_MINUS_1_TO_1());
	particle->degreesPerSecond = DEGREES_TO_RADIANS(rotatePerSecond + rotatePerSecondVariance * RANDOM_MINUS_1_TO_1());
    
    particle->radialAcceleration = radialAcceleration;
    particle->tangentialAcceleration = tangentialAcceleration;
	
	// Calculate the particles life span using the life span and variance passed in
	particle->timeToLive = MAX(0, particleLifespan + particleLifespanVariance * RANDOM_MINUS_1_TO_1());
	
	// Calculate the particle size using the start and finish particle sizes
	GLfloat particleStartSize = startParticleSize + startParticleSizeVariance * RANDOM_MINUS_1_TO_1();
	GLfloat particleFinishSize = finishParticleSize + finishParticleSizeVariance * RANDOM_MINUS_1_TO_1();
	particle->particleSizeDelta = ((particleFinishSize - particleStartSize) / particle->timeToLive) * (1.0 / MAXIMUM_UPDATE_RATE);
	particle->particleSize = MAX(0, particleStartSize);
	
	// Calculate the color the particle should have when it starts its life.  All the elements
	// of the start color passed in along with the variance are used to calculate the star color
	Color4f start = {1.0, 1.0, 1.0, 1.0};
	/*start.red = startColor.red + startColorVariance.red * RANDOM_MINUS_1_TO_1();
	start.green = startColor.green + startColorVariance.green * RANDOM_MINUS_1_TO_1();
	start.blue = startColor.blue + startColorVariance.blue * RANDOM_MINUS_1_TO_1();
	start.alpha = startColor.alpha + startColorVariance.alpha * RANDOM_MINUS_1_TO_1();*/
	
	// Calculate the color the particle should be when its life is over.  This is done the same
	// way as the start color above
	Color4f end = {1.0, 1.0, 1.0, 1.0};
	/*end.red = finishColor.red + finishColorVariance.red * RANDOM_MINUS_1_TO_1();
	end.green = finishColor.green + finishColorVariance.green * RANDOM_MINUS_1_TO_1();
	end.blue = finishColor.blue + finishColorVariance.blue * RANDOM_MINUS_1_TO_1();
	end.alpha = finishColor.alpha + finishColorVariance.alpha * RANDOM_MINUS_1_TO_1();*/
	
	// Calculate the delta which is to be applied to the particles color during each cycle of its
	// life.  The delta calculation uses the life span of the particle to make sure that the 
	// particles color will transition from the start to end color during its life time.  As the game
	// loop is using a fixed delta value we can calculate the delta color once saving cycles in the 
	// update method
	particle->color = start;
	particle->deltaColor.red = ((end.red - start.red) / particle->timeToLive) * (1.0 / MAXIMUM_UPDATE_RATE);
	particle->deltaColor.green = ((end.green - start.green) / particle->timeToLive)  * (1.0 / MAXIMUM_UPDATE_RATE);
	particle->deltaColor.blue = ((end.blue - start.blue) / particle->timeToLive)  * (1.0 / MAXIMUM_UPDATE_RATE);
	particle->deltaColor.alpha = ((end.alpha - start.alpha) / particle->timeToLive)  * (1.0 / MAXIMUM_UPDATE_RATE);
}

- (void)initParticle:(Particle*)particle {
	
	// Init the position of the particle.  This is based on the source position of the particle emitter
	// plus a configured variance.  The RANDOM_MINUS_1_TO_1 macro allows the number to be both positive
	// and negative
	particle->position.x = sourcePosition.x + sourcePositionVariance.x * RANDOM_MINUS_1_TO_1();
	particle->position.y = sourcePosition.y + sourcePositionVariance.y * RANDOM_MINUS_1_TO_1();
    particle->startPos.x = sourcePosition.x;
    particle->startPos.y = sourcePosition.y;
	
	// Init the direction of the particle.  The newAngle is calculated using the angle passed in and the
	// angle variance.
	float newAngle = (GLfloat)DEGREES_TO_RADIANS(angle + angleVariance * RANDOM_MINUS_1_TO_1());
	
	// Create a new Vector2f using the newAngle
	Vector2f vector = Vector2fMake(cosf(newAngle), sinf(newAngle));
	
	// Calculate the vectorSpeed using the speed and speedVariance which has been passed in
	float vectorSpeed = speed + speedVariance * RANDOM_MINUS_1_TO_1();
	
	// The particles direction vector is calculated by taking the vector calculated above and
	// multiplying that by the speed
	particle->direction = Vector2fMultiply(vector, vectorSpeed);
	
	// Set the default diameter of the particle from the source position
	particle->radius = maxRadius + maxRadiusVariance * RANDOM_MINUS_1_TO_1();
	particle->radiusDelta = (maxRadius / particleLifespan) * (1.0 / MAXIMUM_UPDATE_RATE);
	particle->angle = DEGREES_TO_RADIANS(angle + angleVariance * RANDOM_MINUS_1_TO_1());
	particle->degreesPerSecond = DEGREES_TO_RADIANS(rotatePerSecond + rotatePerSecondVariance * RANDOM_MINUS_1_TO_1());
    
    particle->radialAcceleration = radialAcceleration;
    particle->tangentialAcceleration = tangentialAcceleration;
	
	// Calculate the particles life span using the life span and variance passed in
	particle->timeToLive = MAX(0, particleLifespan + particleLifespanVariance * RANDOM_MINUS_1_TO_1());
	
	// Calculate the particle size using the start and finish particle sizes
	GLfloat particleStartSize = startParticleSize + startParticleSizeVariance * RANDOM_MINUS_1_TO_1();
	GLfloat particleFinishSize = finishParticleSize + finishParticleSizeVariance * RANDOM_MINUS_1_TO_1();
	particle->particleSizeDelta = ((particleFinishSize - particleStartSize) / particle->timeToLive) * (1.0 / MAXIMUM_UPDATE_RATE);
	particle->particleSize = MAX(0, particleStartSize);
	
	// Calculate the color the particle should have when it starts its life.  All the elements
	// of the start color passed in along with the variance are used to calculate the star color
	Color4f start = {0, 0, 0, 0};
	start.red = startColor.red + startColorVariance.red * RANDOM_MINUS_1_TO_1();
	start.green = startColor.green + startColorVariance.green * RANDOM_MINUS_1_TO_1();
	start.blue = startColor.blue + startColorVariance.blue * RANDOM_MINUS_1_TO_1();
	start.alpha = startColor.alpha + startColorVariance.alpha * RANDOM_MINUS_1_TO_1();
	
	// Calculate the color the particle should be when its life is over.  This is done the same
	// way as the start color above
	Color4f end = {0, 0, 0, 0};
	end.red = finishColor.red + finishColorVariance.red * RANDOM_MINUS_1_TO_1();
	end.green = finishColor.green + finishColorVariance.green * RANDOM_MINUS_1_TO_1();
	end.blue = finishColor.blue + finishColorVariance.blue * RANDOM_MINUS_1_TO_1();
	end.alpha = finishColor.alpha + finishColorVariance.alpha * RANDOM_MINUS_1_TO_1();
	
	// Calculate the delta which is to be applied to the particles color during each cycle of its
	// life.  The delta calculation uses the life span of the particle to make sure that the 
	// particles color will transition from the start to end color during its life time.  As the game
	// loop is using a fixed delta value we can calculate the delta color once saving cycles in the 
	// update method
	particle->color = start;
	particle->deltaColor.red = ((end.red - start.red) / particle->timeToLive) * (1.0 / MAXIMUM_UPDATE_RATE);
	particle->deltaColor.green = ((end.green - start.green) / particle->timeToLive)  * (1.0 / MAXIMUM_UPDATE_RATE);
	particle->deltaColor.blue = ((end.blue - start.blue) / particle->timeToLive)  * (1.0 / MAXIMUM_UPDATE_RATE);
	particle->deltaColor.alpha = ((end.alpha - start.alpha) / particle->timeToLive)  * (1.0 / MAXIMUM_UPDATE_RATE);
}

- (void)parseParticleConfig:(TBXML*)aConfig {

	TBXMLElement *rootXMLElement = aConfig.rootXMLElement;
	
	// Make sure we have a root element or we cant process this file
	if (!rootXMLElement) {
		NSLog(@"ERROR - ParticleEmitter: Could not find root element in particle config file.");
	}
	
	// First thing to grab is the texture that is to be used for the point sprite
	TBXMLElement *element = [TBXML childElementNamed:@"texture" parentElement:rootXMLElement];
	if (element) {
		NSString *fileName = [TBXML valueOfAttributeNamed:@"name" forElement:element];
        NSString *fileData = [TBXML valueOfAttributeNamed:@"data" forElement:element];
					
		if (fileName && !fileData) {		
			// Create a new texture which is going to be used as the texture for the point sprites. As there is
            // no texture data in the file, this is done using an external image file
			texture = [[Texture2D alloc] initWithImage:[UIImage imageNamed:fileName] filter:GL_LINEAR];
		}
        
        // If texture data is present in the file then create the texture image from that data rather than an external file
        if (fileData) {
            texture = [[Texture2D alloc] initWithImage:[UIImage imageWithData:[[NSData dataWithBase64EncodedString:fileData] gzipInflate]] filter:GL_LINEAR];
        }
	}
	
	// Load all of the values from the XML file into the particle emitter.  The functions below are using the
	// TBXMLAdditions category.  This adds convenience methods to TBXML to help cut down on the code in this method.
    emitterType = [aConfig intValueFromChildElementNamed:@"emitterType" parentElement:rootXMLElement];
	sourcePosition = [aConfig vector2fFromChildElementNamed:@"sourcePosition" parentElement:rootXMLElement];
	sourcePositionVariance = [aConfig vector2fFromChildElementNamed:@"sourcePositionVariance" parentElement:rootXMLElement];
	speed = [aConfig floatValueFromChildElementNamed:@"speed" parentElement:rootXMLElement];
	speedVariance = [aConfig floatValueFromChildElementNamed:@"speedVariance" parentElement:rootXMLElement];
	particleLifespan = [aConfig floatValueFromChildElementNamed:@"particleLifeSpan" parentElement:rootXMLElement];
	particleLifespanVariance = [aConfig floatValueFromChildElementNamed:@"particleLifespanVariance" parentElement:rootXMLElement];
	angle = [aConfig floatValueFromChildElementNamed:@"angle" parentElement:rootXMLElement];
	angleVariance = [aConfig floatValueFromChildElementNamed:@"angleVariance" parentElement:rootXMLElement];
	gravity = [aConfig vector2fFromChildElementNamed:@"gravity" parentElement:rootXMLElement];
    radialAcceleration = [aConfig floatValueFromChildElementNamed:@"radialAcceleration" parentElement:rootXMLElement];
    tangentialAcceleration = [aConfig floatValueFromChildElementNamed:@"tangentialAcceleration" parentElement:rootXMLElement];
	startColor = [aConfig color4fFromChildElementNamed:@"startColor" parentElement:rootXMLElement];
	startColorVariance = [aConfig color4fFromChildElementNamed:@"startColorVariance" parentElement:rootXMLElement];
	finishColor = [aConfig color4fFromChildElementNamed:@"finishColor" parentElement:rootXMLElement];
	finishColorVariance = [aConfig color4fFromChildElementNamed:@"finishColorVariance" parentElement:rootXMLElement];
	maxParticles = [aConfig floatValueFromChildElementNamed:@"maxParticles" parentElement:rootXMLElement];
	startParticleSize = [aConfig floatValueFromChildElementNamed:@"startParticleSize" parentElement:rootXMLElement];
	startParticleSizeVariance = [aConfig floatValueFromChildElementNamed:@"startParticleSizeVariance" parentElement:rootXMLElement];	
	finishParticleSize = [aConfig floatValueFromChildElementNamed:@"finishParticleSize" parentElement:rootXMLElement];
	finishParticleSizeVariance = [aConfig floatValueFromChildElementNamed:@"finishParticleSizeVariance" parentElement:rootXMLElement];
	duration = [aConfig floatValueFromChildElementNamed:@"duration" parentElement:rootXMLElement];
	blendFuncSource = [aConfig intValueFromChildElementNamed:@"blendFuncSource" parentElement:rootXMLElement];
    blendFuncDestination = [aConfig intValueFromChildElementNamed:@"blendFuncDestination" parentElement:rootXMLElement];
	
	// These paramters are used when you want to have the particles spinning around the source location
	maxRadius = [aConfig floatValueFromChildElementNamed:@"maxRadius" parentElement:rootXMLElement];
	maxRadiusVariance = [aConfig floatValueFromChildElementNamed:@"maxRadiusVariance" parentElement:rootXMLElement];
	radiusSpeed = [aConfig floatValueFromChildElementNamed:@"radiusSpeed" parentElement:rootXMLElement];
	minRadius = [aConfig floatValueFromChildElementNamed:@"minRadius" parentElement:rootXMLElement];
	rotatePerSecond = [aConfig floatValueFromChildElementNamed:@"rotatePerSecond" parentElement:rootXMLElement];
	rotatePerSecondVariance = [aConfig floatValueFromChildElementNamed:@"rotatePerSecondVariance" parentElement:rootXMLElement];
	
	// Calculate the emission rate
	emissionRate = maxParticles / particleLifespan;

}

- (void)setupArrays {
	// Allocate the memory necessary for the particle emitter arrays
	particles = malloc( sizeof(Particle) * maxParticles);
	vertices = malloc( sizeof(PointSprite) * maxParticles);
	
	// If one of the arrays cannot be allocated throw an assertion as this is bad
	NSAssert(particles && vertices, @"ERROR - ParticleEmitter: Could not allocate arrays.");
	
	// Generate the vertices VBO
	glGenBuffers(1, &verticesID);
	
	// By default the particle emitter is inactive when created
	active = NO;
	
	// Set the particle count to zero
	particleCount = 0;
	
	// Reset the elapsed time
	elapsedTime = 0;	
}

@end

