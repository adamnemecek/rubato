/*
 *  JGAccessorMacros_init.h
 *  AndreasMeloProjects
 *
 *  Created by jg on Wed Aug 29 2001.
 *  Copyright (c) 2001 __CompanyName__. All rights reserved.
 *
 */

#include "JGAccessorMacrosFlexBegin.h"

#define accessor_flex( type, var, setVar ) accessor_init(type,var,setVar)
#define scalarAccessor_flex( type, var, setVar ) scalarAccessor_init(type,var,setVar)

#include "JGAccessorMacrosFlexEnd.h"
