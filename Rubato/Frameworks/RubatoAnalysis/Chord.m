#import "Chord.h"
#import "ChordSequence.h"
#import <RubatoDeprecatedCommonKit/commonkit.h>
#import <Rubette/MatrixEvent.h>

#import "ThirdStream.h"

#define EH_space 3

@implementation Chord

- init;
{
    int i,j;
    [super init];

    myOwnerSequence = nil;
    myPitchList = NULL;
    myPitchCount = 0;
    myPitchClasses = 0;
    myOnset = 0;
    myThirdStreamList = [[[RefCountList alloc]init]ref];
    // jg added initialization for myRiemannMatrix and myLevelMatrix on Mac.
    // possible that on Mac no initialization of Memory with zeros take place...
    // there was a Problem in ChordInspector, when in Harmo-Rubette GenerateRiemannLogic 
    // is not clicked.
    for(i=0; i<MAX_FUNCTION; i++)
      for(j=0; j<MAX_TONALITY; j++) {
        myRiemannMatrix[i][j]=0.0;
        myLevelMatrix[i][j]=0.0;
      }
    mySupportStart = MAX_LOCUS;
    for(i=0;i<=PATHNUMBER;i++){
	myLocus[i] = MAX_LOCUS;
	}
    for (i=0; i<MAX_TONALITY; i++)
	myPitchClassWeights[i] = 0.0;
    myWeight = 0.0;
    isWeightCalculated  = NO;
    return self;
}

- initOwner:aChordSequence;
{
    [self init];
    [self setOwnerSequence:aChordSequence];
    return self;
}


- (void)dealloc;
{
    /* do NXReference houskeeping */
    
    free(myPitchList);
    [myThirdStreamList release];
    [super dealloc];
}

- copyWithZone:(NSZone*)zone;
{
    Chord *myCopy = JGSHALLOWCOPY;//[super copyWithZone:zone];
    int i;
    myCopy->myPitchList = malloc(myPitchCount*sizeof(double));
    for (i=0; i<myPitchCount; i++) {
	myCopy->myPitchList[i] = myPitchList[i];
    }
    myCopy->myThirdStreamList = [myThirdStreamList mutableCopyWithZone:zone]; // mutability!
    return myCopy;
}

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    int i;
//    [super initWithCoder:aDecoder];
    /* class-specific code goes here */
    
    myOwnerSequence = [aDecoder decodeObject]; // jgreferences?: was: +retain. In encode:conditionalEncoding
    myThirdStreamList = [[aDecoder decodeObject] retain];
    
    [aDecoder decodeValueOfObjCType:"i" at:&myPitchCount];
    myPitchList = realloc(myPitchList, myPitchCount*sizeof(double));
    for(i=0; i<myPitchCount; i++) 
	[aDecoder decodeValueOfObjCType:"d" at:&myPitchList[i]];
    [aDecoder decodeValueOfObjCType:"S" at:&myPitchClasses];
    [aDecoder decodeValueOfObjCType:"d" at:&myOnset];
  
    
    for(i=0;i<MAX_FUNCTION*MAX_TONALITY;i++) {
	[aDecoder decodeValueOfObjCType:"d" at:&myRiemannMatrix[i/MAX_TONALITY][i%MAX_TONALITY]];
	[aDecoder decodeValueOfObjCType:"d" at:&myLevelMatrix[i/MAX_TONALITY][i%MAX_TONALITY]];
    }
    
    for(i=0; i<PATHNUMBER+1; i++) 
	[aDecoder decodeValueOfObjCType:"s" at:&myLocus[i]];
    [aDecoder decodeValueOfObjCType:"s" at:&mySupportStart];
    
    [aDecoder decodeValueOfObjCType:"c" at:&isWeightCalculated];
    [aDecoder decodeValueOfObjCType:"d" at:&myWeight];
    for(i=0; i<MAX_TONALITY; i++) 
	[aDecoder decodeValueOfObjCType:"d" at:&myPitchClassWeights[i]];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    int i;
//    [super encodeWithCoder:aCoder];
    /* class-specific archiving code goes here */
    
    [aCoder encodeConditionalObject:myOwnerSequence];
    [aCoder encodeObject:myThirdStreamList];
    
    [aCoder encodeValueOfObjCType:"i" at:&myPitchCount];
    for(i=0; i<myPitchCount; i++) 
	[aCoder encodeValueOfObjCType:"d" at:&myPitchList[i]];
    [aCoder encodeValueOfObjCType:"S" at:&myPitchClasses];
    [aCoder encodeValueOfObjCType:"d" at:&myOnset];
  
    
    for(i=0;i<MAX_FUNCTION*MAX_TONALITY;i++) {
	[aCoder encodeValueOfObjCType:"d" at:&myRiemannMatrix[i/MAX_TONALITY][i%MAX_TONALITY]];
	[aCoder encodeValueOfObjCType:"d" at:&myLevelMatrix[i/MAX_TONALITY][i%MAX_TONALITY]];
    }
    
    for(i=0; i<PATHNUMBER+1; i++) 
	[aCoder encodeValueOfObjCType:"s" at:&myLocus[i]];
    [aCoder encodeValueOfObjCType:"s" at:&mySupportStart];
    
    [aCoder encodeValueOfObjCType:"c" at:&isWeightCalculated];
    [aCoder encodeValueOfObjCType:"d" at:&myWeight];
    for(i=0; i<MAX_TONALITY; i++) 
	[aCoder encodeValueOfObjCType:"d" at:&myPitchClassWeights[i]];
}


- (NSString *)inspectorNibFile;
{
    return @"ChordInspector.nib";
}

- ownerSequence;
{
    return myOwnerSequence;
}


- setOwnerSequence:aChordSequence;
{
    if (!myOwnerSequence && [aChordSequence isKindOfClass:[ChordSequence class]])
	myOwnerSequence = aChordSequence;
    return self;
}


/* tone management */
- (BOOL)hasPitchClass:(int)aPitchInt;
{
    return (myPitchClasses & 1<<modTwelve(aPitchInt)) ? YES : NO;
}



- (BOOL) hasPitch:(double)aPitch;
{
    int i;
    for (i=0; i<myPitchCount && myPitchList[i]!=aPitch; i++);
    return i<myPitchCount;
}

- (BOOL)hasToneEvent:(MatrixEvent *)anEvent;
{
    return [anEvent isKindOfClass:[MatrixEvent class]] && [anEvent isSuperspaceFor: EH_space] &&
	[anEvent doubleValueAtIndex:indexE]==myOnset &&	[self hasPitch:[anEvent doubleValueAtIndex:indexH]];
}

/*- (int)addPitchClass:(int)index;
{
    return myPitchClasses | 1<<modTwelve(index);
}*/

/*- (int)removePitchClass:(int)index;
{
    return myPitchClasses & ~(1<<modTwelve(index));
}*/

- addToneEvent:(MatrixEvent *)anEvent;
{
    if([anEvent isKindOfClass:[MatrixEvent class]] && [anEvent isSuperspaceFor:EH_space] &&
	 ([anEvent doubleValueAtIndex:indexE]==myOnset || !myPitchCount)){
	
	if(!myPitchCount) myOnset = [anEvent doubleValueAtIndex:indexE]; /* set first onset */
	[self addPitch:[anEvent doubleValueAtIndex:indexH]];
    }
    return self;
}

- removeToneEvent:anEvent;
{
    if([self hasToneEvent:anEvent]){
	[self removePitch:[anEvent doubleValueAtIndex:indexH]];
    }
    return self;
}

- addPitch:(double)aPitch;
{
    if(![self hasPitch:aPitch]){
	int i;
	myPitchCount++;
	myPitchList =  realloc(myPitchList, myPitchCount*sizeof(double));
	for (i=myPitchCount-1; i>0 && myPitchList[i]>aPitch; i--) {
	    myPitchList[i] = myPitchList[i-1];
	}
	myPitchList[i] = aPitch;
	/* reset the pitch classes and rebuild from list */
	[self updatePitchClasses];
    }
    return self;
}

- removePitch:(double)aPitch;
{
    if([self hasPitch:aPitch]){
	int i;
	for (i=0; i<myPitchCount-1; i++) {
	    if (myPitchList[i]>=aPitch)
		myPitchList[i] = myPitchList[i+1];
	}
	myPitchCount--;
	//myPitchList =  realloc(myPitchList, myPitchCount*sizeof(double));
	/* reset the pitch classes and rebuild from list */
	[self updatePitchClasses];
    }
    return self;
}

- (double) onset;
{
    return myOnset;
}

- (const double *)pitchList;
{
    return myPitchList;
}

- (unsigned short)pitchClasses;
{
    return myPitchClasses;
}

/* chord Methode f�r Quinttransformation */
- (unsigned short) fifthPitchClasses;
{
    int i;
    unsigned short fifthClasses = 0;
    for(i=0; i<12; i++){
	if([self hasPitchClass:i])
	    fifthClasses = fifthClasses | 1<<modTwelve(i*7); 
	    }
    return fifthClasses;
}

- thirdStreamList;
{
    return myThirdStreamList;
}


/* counting tones */
- (int)pitchCount;
{
    return myPitchCount;
}


- (int)pitchClassCount;
{
    int i, d = 0;
    for(i=0; i<12; i++){
	if(myPitchClasses & 1<<i)
	    d++;
	}
    return d;
}

/* Weight and RiemannMatrix calculation maintenance */
- invalidate;
{
    int i;
    [self updatePitchClasses];
    [self invalidateWeight];
    for(i=0;i<=PATHNUMBER;i++){
	myLocus[i] = MAX_LOCUS;
	}
    
    return self;
}

- invalidateWeight;
{
    int i;
    if(isWeightCalculated) /* reset myPitchClassWeights */
	for (i=0; i<MAX_TONALITY; i++)
	    myPitchClassWeights[i] = 0.0;
    
    isWeightCalculated = NO;
    return self;
}


- updatePitchClasses;
{
    int i;
    unsigned int oldPitchClasses = myPitchClasses;
    myPitchClasses = 0;
    for (i=0; i<myPitchCount; i++) {
	myPitchClasses = myPitchClasses | 1<<pitchClassTwelve(myPitchList[i],
						[myOwnerSequence pitchReference],
						[myOwnerSequence semitoneUnit]);
    }
    if(myPitchClasses!=oldPitchClasses) {/* reset weigths then and recalc ThirdStream*/
	[self invalidateWeight];
	[self calcThirdStreamList];
    }
    return self;
}

- updateSupport;
{
    int i;
    [self calcSupportStart];
    for(i=0;i<=PATHNUMBER;i++)
	myLocus[i] = mySupportStart;

    return self;
}


/* management of subchords */
- (BOOL)isSubChordOfPitchClasses:(unsigned short)pitchClasses;
{
    return myPitchClasses == (myPitchClasses & pitchClasses);
}



- (BOOL)isSubChordOf:aChord;
{

    return [aChord isKindOfClass:[Chord class]] && 
	[self isSubChordOfPitchClasses:[aChord pitchClasses]]; 
}

- (BOOL)isSubChordOfStream:aThirdStream;
{
    return [aThirdStream isKindOfClass:[ThirdStream class]] &&
	[self isSubChordOfPitchClasses:[aThirdStream pitchClasses]];
}

- (int)locusOfPath:(int)pathNumber;
{
    pathNumber = mod(pathNumber,PATHNUMBER+1);
    return myLocus[pathNumber];
}
- (void)setLocusOfPath:(int)pathNumber toIndex:(int)idx; // jg added
{
  myLocus[pathNumber]=idx;
}

- (int)workLocus;
{
    return myLocus[PATHNUMBER];
}

- setRiemannLocusOf:(int)pathNumber to:(int)locus;
{
    pathNumber = mod(pathNumber,PATHNUMBER+1);
    locus = locus<MAX_LOCUS ? locus : MAX_LOCUS;
    myLocus[pathNumber] = locus;
    return self;
}

- setWorkLocus:(int)locus;
{
    return [self setRiemannLocusOf:PATHNUMBER to:locus];
}

- retainWorkLocus;
{
    [self setRiemannLocusOf:PATHNUMBER-1 to:myLocus[PATHNUMBER]];
    return self;
}


- resetWorkLocusToSupportStart;
{
    [self setRiemannLocusOf:PATHNUMBER to:mySupportStart];
    return self;
}


- calcThirdStreamList;
{
    int i, j, c=[self pitchClassCount], cc = 11;
    ThirdStream *stream = [[ThirdStream alloc]init];
    [myThirdStreamList freeObjects];
    for(j=0;j<12;j++){
	if([self hasPitchClass:j]){
	    [stream setBasis:j];
	    for(i=c-1;i<CardLimit(cc); i++){
		if([self isSubChordOfPitchClasses:[[stream setThirdList:i] pitchClasses]]){
	
		    if([stream length]<cc)
			[myThirdStreamList freeObjects];
	
		    cc = [stream length]; 
		    [myThirdStreamList addObject:[[[[ThirdStream alloc]init] setBasis:j] setThirdList:i]];
		}
	    }
	}
    }
    [stream release];
    return self;
}

- (double)calcRiemannValueAtFunction:(int)function andTonic:(int)tonic;
{
    switch([myOwnerSequence method]) {
	case MAZZOLA: {
	    int j, c = [myThirdStreamList count]; /* c is always positive */
	    double val = 0.0;
	
	    for(j=0; j<c; j++) {
		
		/* add all thirdstream contributions */
		val += [[myThirdStreamList objectAt:j] riemannWeightWithFunctionScale:
		    (void *)[myOwnerSequence functionScale] atFunction:function andTonic:tonic];
	    }
		/* take average */
	    return    val / (double)c;
	}
	case NOLL: return [self calcNollRiemannValueAtFunction:function andTonic:tonic 
			genericWeight:[myOwnerSequence nollMatrix]];
	case FLEISCHER : return 0.0;
    }
    return 0.0;
}

- (double)calcRiemannValueAtLocus:(int)locus;
{
    return [self calcRiemannValueAtFunction:[self functionAt:locus]+[self modeAt:locus]*3
			andTonic:[self tonicAt:locus]];
}

- calcRiemannMatrix;
{
    int f, t;
    /* first fix the tonic, then the function */
    for(t=0; t<MAX_TONALITY; t++){
	for(f=0; f<MAX_FUNCTION; f++){
	    myRiemannMatrix[f][t]= [self calcRiemannValueAtFunction:f andTonic:t];
	}
    }
    return self;
}

/* Noll-Methoden */
/* neue RiemannFunktionsberechnung, kommt in Chord,
 * ersetzt bei Noll-Switch = YES die Methode
 * calcRiemannValueAtFunction:(int)function andTonic:(int)tonic;
 * benutzt die interne C-Funktion "Riemann[X_]" ~ 
 * riemann(int function, int tonic, unsigned short chordBits) von Noll aus harmoTables.c 
 */
- (double)calcNollRiemannValueAtFunction:(int)function andTonic:(int)tonic 
			genericWeight:(double ***)nollRiemannWeight;
{
    int  fifthClasses = [self fifthPitchClasses];
    tonic = modTwelve(tonic*7); /* the fifth class of the tonic */
    
    if(function == 1)
	return MAX(riemann(function, tonic,fifthClasses,nollRiemannWeight),
		riemann(6,tonic,fifthClasses,nollRiemannWeight));

    if(function == 5)
	return MAX(riemann(function, tonic,fifthClasses,nollRiemannWeight),
		riemann(7,tonic,fifthClasses,nollRiemannWeight));
    
    return riemann(function, tonic,fifthClasses,nollRiemannWeight);
}


- (double)riemannAtLocus:(int)locus;
{
    return myRiemannMatrix[locus/MAX_TONALITY][locus%MAX_TONALITY];
}

- (double)maxRiemannValue;
{
    int locus;
    double maxval = 0.0, val = 0.0;
    for(locus=0; locus<MAX_LOCUS; locus++) {
	val=[self riemannAtLocus:locus];
	maxval = val>maxval ? val : maxval;
    }
    return maxval;
}

- calcLevelMatrixWithLevel:(double)level;
{
    int f, t;
    level = fabs(level);

    for (t=0; t<MAX_TONALITY; t++) {
	for (f=0; f<MAX_FUNCTION; f++){
	    myLevelMatrix[f][t] = myRiemannMatrix[f][t]>=level ? myRiemannMatrix[f][t] : 0.0;
	}
    }
    
    [self updateSupport];

    return self;
}

- (double)levelAtFunction:(int)function andTonality:(int)tonality;
{
    return myLevelMatrix [mod(function,6)][modTwelve(tonality)];
}

- setLevel:(double)level atFunction:(int)function andTonality:(int)tonality;
{
    myLevelMatrix[mod(function,6)][modTwelve(tonality)] = level;
    [self updateSupport];
    return self;
}

- (double)levelAtLocus:(int)locus;
{
    if(locus<MAX_LOCUS)
	return myLevelMatrix[locus/MAX_TONALITY][locus%MAX_TONALITY];
    else
	return 0.0;
}

- (double)levelAtPath:(int)pathNumber;
{
    return [self levelAtLocus:myLocus[pathNumber]];
}

- (double)maxLevel;
{
    int locus;
    double maxval = 0.0, val = 0.0;
    for(locus=0; locus<MAX_LOCUS; locus++) {
	val=[self levelAtLocus:locus];
	maxval = val>maxval ? val : maxval;
    }
    return maxval;
}

- restrictLevelMatrixTo:(int)tonalities :(int)modeFunctions;
{
    int i;
    for(i=0; i<MAX_LOCUS; i++){
	if(tonalities & 1<<(i%MAX_TONALITY) /* column of index i */
		    | modeFunctions & 1<<(i/MAX_TONALITY)) /* row of index i */
	    myLevelMatrix[i/MAX_TONALITY][i%MAX_TONALITY]=0.0;
    }
    [self updateSupport];
    return self;
}

- restrictLevelMatrixAtFunction:(int)function andTonality:(int)tonality;
{
    return [self setLevel:0.0 atFunction:function andTonality:tonality];
}

- restrictLevelMatrixAtLocus:(int)locus;
{
    if (locus<MAX_LOCUS)
	[self restrictLevelMatrixAtFunction:(locus/MAX_TONALITY) andTonality:(locus%MAX_TONALITY)];
    return self;
}


- (int)supportCard;
{
    int i, s=0;
    if(mySupportStart<MAX_LOCUS){
	for(i=0; i<MAX_LOCUS; i++)
	    if([self levelAtLocus:i])
		s+=1;
    }
    return s;
}

- (int)calcSupportStart;
{
    int i;
    for(i=0; i<MAX_LOCUS && ![self levelAtLocus:i]; i++);
    mySupportStart = i;
    return mySupportStart;
}

- (int)supportStart;
{
    return mySupportStart;
}

/* returns the next locus with non-vanishing level value; or 72 if it is the last */
- (int)nextSupportIndexTo:(int)index;
{
    int i;
    if(index<MAX_LOCUS-2) { /* only then we got a chance */
	for(i = index+1; i<MAX_LOCUS && ![self levelAtLocus:i]; i++);
	return i;
    }
    return MAX_LOCUS;
}

- (BOOL)maxSupportIndexAt:(int)index;
{
    return mySupportStart == MAX_LOCUS || MAX_LOCUS == [self nextSupportIndexTo:index];
}

/* checks whether work index is maximal support */
- (BOOL)maxWorkSupportIndex;
{
    return [self maxSupportIndexAt:myLocus[PATHNUMBER]];
}

- (int)tonicAt:(int)index;
{
    return locusOf(index).RieTon;
}

- (int)modeAt:(int)index;
{
    return locusOf(index).RieVal <= 2 ? 0 : 1;
}

- (int)functionAt:(int)index;
{
    return mod(locusOf(index).RieVal,3);
}


/* relative weights of tones of a chord */
- (double)relativeWeightOfTone:(int)toneIndex atLocus:(int)locus;
{
    if (!myPitchCount || toneIndex<0 || toneIndex>=myPitchCount)
	return 0.0;
    if(!isWeightCalculated) {
	int i;
	double intraProfile = [myOwnerSequence intraProfile];
	for (i=0; i<MAX_TONALITY; i++) 
	    myPitchClassWeights[i] = 0.0;
	    
	if(intraProfile>=0 && intraProfile<1 && [self levelAtLocus:locus]){
	    if(myPitchCount == 1)
		myPitchClassWeights[modTwelve(myPitchList[0])] = 1.0;
	    else{
		id copyChord = [self copy];
		/* now calculate all the pitchClassWeights at once */
		for (i=0; i<myPitchCount; i++) {
		    if (myPitchClassWeights[modTwelve(myPitchList[i])]==0.0) {
		    /* it's assumed not to be calculated if 0.0 */
			double indexToneVal;
			[copyChord removePitch:myPitchList[i]];
			indexToneVal = [copyChord calcRiemannValueAtLocus:locus];
			myPitchClassWeights[modTwelve(myPitchList[i])] = 1/(intraProfile + (1-intraProfile)*indexToneVal/[self levelAtLocus:locus]); /* HIER KEHRWERT NEHMEN */
			[copyChord addPitch:myPitchList[i]];
		    }
		}
		[copyChord release];
	    }
	    isWeightCalculated = YES; /* weights are usable now */
	}
    }
    return myPitchClassWeights[modTwelve(myPitchList[toneIndex])];
}
- (BOOL)isWeightCalculated;
{
    return isWeightCalculated;
}

/*best weight management*/
- (double)bestWeight;
{
    return myWeight;
} 

- setBestWeight:(double)weight;
{
    myWeight = fabs(weight);
    return self;
} 


/* Default implementation for the Ordering Protocol */
- (int)compareTo:anObject;
{
    if ([self equalTo:anObject])
	return 0;
    else if ([self largerThan:anObject])
	return 1;
    else
	return -1;
}


- (BOOL)equalTo:anObject;
{
    if (self!=anObject) {
	if ([anObject isKindOfClass:[self class]]) {
	    if ([anObject onset]==myOnset && [anObject pitchCount]==myPitchCount) {
		int i;
		const double *pitchList = [anObject pitchList];
		for (i=0; i<myPitchCount && pitchList[i]==myPitchList[i]; i++); 
		return i==myPitchCount;
	    }
	}
	return NO;
    }
    return YES; /*self is equal to self */
}

- (BOOL)largerThan:anObject;
{
    return ![self smallerEqualThan:anObject];
}

- (BOOL)smallerThan:anObject; 
{
    if (self!=anObject) {
	if ([anObject isKindOfClass:[self class]]) {
	    if ([anObject onset]>myOnset) {
		if([anObject onset]==myOnset) {
		    if ([anObject pitchCount]>myPitchCount)
			return YES; /* equal onsets but anObject has more tones */
		    else if ([anObject pitchCount]==myPitchCount) {
			int i;
			const double *pitchList = [anObject pitchList];
			for (i=0; i<myPitchCount && myPitchList[i]<pitchList[i]; i++); 
			return i==myPitchCount; /* our every pitch must be smaller */
		    }
		    return NO; /* equal onsets, but we have more tones */
		}
		return YES; /* myOnset smaller */
	    }
	    return NO; /* onset of anObject is smaller equal to myOnset */
	}
	return self<anObject;
    }
    return NO; /* self can't be smaller than self */
}

/*logically redundant but not as methods */
- (BOOL)largerEqualThan:anObject;
{
    return ![self smallerThan:anObject];
}

- (BOOL)smallerEqualThan:anObject;
{
    if (self!=anObject) {
	if ([anObject isKindOfClass:[self class]]) {
	    if ([anObject onset]>=myOnset) {
		if([anObject onset]==myOnset) {
		    if ([anObject pitchCount]>myPitchCount)
			return YES; /* equal onsets but anObject has more tones */
		    if ([anObject pitchCount]==myPitchCount) {
			int i;
			const double *pitchList = [anObject pitchList];
			for (i=0; i<myPitchCount && myPitchList[i]<=pitchList[i]; i++); 
			return i==myPitchCount; /* our every pitch must be smallerEqual */
		    }
		    return NO; /* equal onsets, but we have more tones */
		}
		return YES; /* myOnset smaller */
	    }
	    return NO; /* onset of anObject is smaller than myOnset */
	}
	return self<anObject;
    }
    return YES; /*self is equal to self */
}

@end