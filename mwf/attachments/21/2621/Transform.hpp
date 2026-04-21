//! \file Transform.hpp
//! Interface of the Transform class.

#ifndef GOSU_TRANSFORM_HPP
#define GOSU_TRANSFORM_HPP

namespace Gosu
{
    // Provides a wrapper for OpenGL matrix transformations.
    class Transform
    {
        double matrix[16];
        
    protected:
        friend class DrawOp;
        void begin();
        void end();
        
    public:
        //! Creates a transformation from an arbitrary matrix stored in
        //! column-major mode.
        Transform(const double matrix[16]);
        
        //! Convenience function that creates a rotation transform.
        static Transform rotate(double angle);
        //! Convenience function that creates a translation transform.
        static Transform translate(double x, double y);
        //! Convenience function that creates a uniform scaling transform.
        static Transform scale(double factor);
        //! Convenience function that creates a non-uniform scaling transform.
        static Transform scale(double factorX, double factorY);
        
        // TODO make these combinable. Maybe change to a proper Matrix class?
    };
}

#endif
