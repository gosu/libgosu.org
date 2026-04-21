#include <Gosu/Transform.hpp>
#include <Gosu/Math.hpp>
#include <GosuImpl/Graphics/Common.hpp>
#include <algorithm>
#include <cmath>

Gosu::Transform::Transform(const double matrix[16])
{
    std::copy(matrix, matrix + 16, this->matrix);
}

void
Gosu::Transform::begin()
{
    glPushMatrix();
    glMultMatrixd(matrix);
}

void
Gosu::Transform::end()
{
    glPopMatrix();
}

Gosu::Transform
Gosu::Transform::rotate(double angle)
{
    double c = std::cos(angle / 180 * Gosu::pi);
    double s = std::sin(angle / 180 * Gosu::pi);
    double matrix[16] = {
        +c, +s, 0, 0,
        -s, +c, 0, 0,
        0,  0,  1, 0,
        0,  0,  0, 1
    };
    return Gosu::Transform(matrix);
}

Gosu::Transform
Gosu::Transform::translate(double x, double y)
{
    double matrix[16] = {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        x, y, 0, 1
    };
    return Gosu::Transform(matrix);
}

Gosu::Transform
Gosu::Transform::scale(double factor)
{
    double matrix[16] = {
        factor, 0,      0, 0,
        0,      factor, 0, 0,
        0,      0,      1, 0,
        0,      0,      0, 1
    };
    return Gosu::Transform(matrix);
}

Gosu::Transform
Gosu::Transform::scale(double factorX, double factorY)
{
    double matrix[16] = {
        factorX, 0,       0, 0,
        0,       factorY, 0, 0,
        0,       0,       1, 0,
        0,       0,       0, 1
    };
    return Gosu::Transform(matrix);
}
