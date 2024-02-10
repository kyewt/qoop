<p align="center">how to use
<p align="left">classes, enums and interfaces must be created in modules and be the sole return value of the module.

<p align="center">classes
<p align="left">classes are created in an unfinalized state, assigned members including fields, properties, methods and their static counterparts, along with a constructor and destructor.
<p align="left">use the qoop.qclass.extend function to create a new unfinalized class. it has 3 parameters and an optional tuple; className (mandatory), inheritedClassName (optional), abstract (optional), interfaces (optional tuple).
<p align="left">the following are ways to create different types of classes:
<p align="left">local class = qoop.qclass.extend("className") - a class that does not inherit from anything and IS NOT ABSTRACT, and implements no interfaces.
<p align="left">local class = qoop.qclass.extend("classNameB", "classNameA") - a class that inherits from "classNameA" and IS NOT ABSTRACT and implements no interfaces.
<p align="left">local class = qoop.qclass.extend("className", nil, true) - a class that does not inherit from anything and IS ABSTRACT and implements no interfaces.
<p align="center">assigning members to unfinalized classes
<p align="left">the member types are as follows:
<p align="left">fields, properties, methods, static fields, static properties, static methods, method overrides, field overrides, property overrides, constructors, and destructors.
<p align="left">the member assignment functions may be accessed through the class you just created. they are as follows:
<p align="left">setField, setProperty, setMethod, setStaticField, setStaticProperty, setStaticMethod, overrideField, overrideProperty, overrideMethod, setConstructor, setDestructor.
<p align="left">the parameters:
<p align="left">setField: name, value, readonly - (string, any, boolean)
<p align="left">setProperty: name, getter, setter, init - (string, func, func, optional func)
<p align="left">setMethod: name, func (string, func)
<p align="left">setStaticField: name, value, readonly - (string, any, boolean)
<p align="left">setStaticProperty: name, getter, setter - (string, func, func)
<p align="left">setStaticMethod: name, func (string, func)
<p align="left">overrideField: name, value, readonly - (string, any, boolean)
<p align="left">overrideProperty: name, getter, setter - (string, func, func)
<p align="left">overrideMethod: name, func - (string, func)
<p align="left">setConstructor: func - (func)
<p align="left">setDestructor: func - (func)
<p align="center">finalizing and returning a class
<p align="left">finalizing a class is done as follows:
<p align="left">class:finalize()
<p align="left">after finalization, return the class.
<p align="center">accessing and instantiating a class
<p align="left">accessing a class is done as follows:
<p align="left">qoop.qclass.classes[className]
<p align="left">instantiating a class:
<p align="left">qoop.qclass.classes[className]()
<p align="center">on property getters, setters and init, methods, constructors, and destructors
<p align="left">the functions given to these members will be passed a special argument when called. for an instance of a class, it will be a reference to the instance. for a class being accessed through a static member, it will be the class.
<p align="center">on readonly and init
<p align="left">these two parameters if true will disallow setting of the field or property outside of the constructor.
