#ifndef COMMON_TRANSFORMER_HPP
#define COMMON_TRANSFORMER_HPP

#include <Gosu/Graphics.hpp>
#include <Gosu/Input.hpp>
#include "Common/System.hpp"
#include <boost/foreach.hpp>

enum Transform
{
    trGameSmall, trGameLarge, trGameTop, trGameBottom,
    trMenuSmall, trMenuLarge, trMenuTop, trMenuBottom,
    trOverworldSmall, trOverworldLarge, trEditor = trOverworldLarge, trNum
};

class Transformer
{
    typedef Gosu::Transform Transforms[3];

    static const Transforms& forwardTransforms(Transform tr)
    {
        static const Transforms transforms[trNum] = {
            // game small
            { Gosu::translate(0, 0), Gosu::rotate(0), Gosu::scale(480.0/600) },
            // game large
            { Gosu::translate(0, 0), Gosu::rotate(0), Gosu::scale(1024.0/800) },
            // game top
            { Gosu::translate(512, 0), Gosu::rotate(90), Gosu::scale(768.0/600) },
            // game bottom
            { Gosu::translate(512, 768), Gosu::rotate(-90), Gosu::scale(768.0/600) },
            // menu small
            { Gosu::translate(0, 0), Gosu::rotate(0), Gosu::scale(0.5) },
            // menu large
            { Gosu::translate(32, 64), Gosu::rotate(0), Gosu::scale(1) },
            // menu top
            { Gosu::translate(512, 0), Gosu::rotate(90), Gosu::scale(512.0/640) },
            // menu bottom
            { Gosu::translate(512, 768), Gosu::rotate(-90), Gosu::scale(512.0/640) },
            // overworld small
            { Gosu::translate(0, 0), Gosu::rotate(0), Gosu::scale(0.5) },
            // overworld large & editor does not transform anything
            { Gosu::translate(0, 0), Gosu::rotate(0), Gosu::scale(1) },
        };
        return transforms[tr];
    }

    static Transforms& reverseTransforms(Transform tr)
    {
        static bool initialized[trNum] = { false };
        static Transforms transforms[trNum];
        
        if (not initialized[tr])
        {
            const Transforms& forward = forwardTransforms(tr);
        
            transforms[tr][0] = Gosu::translate(-forward[0][12], -forward[0][13]);
            transforms[tr][1] = forward[1];
            transforms[tr][1][1] *= -1;
            transforms[tr][1][4] *= -1;
            transforms[tr][2] = Gosu::scale(1.0/forward[2][0], 1.0/forward[2][5]);
            initialized[tr] = true;
        }
        
        return transforms[tr];
    }
    
    static void applyTransform(const Gosu::Transform& transform, float& x, float& y)
    {
        float in[4] = { x, y, 0, 1 };
        float out[4] = { 0, 0, 0, 0 };
        for (int i = 0; i < 4; ++i)
            for (int j = 0; j < 4; ++j)
                out[i] += in[j] * transform[j * 4 + i];
        x = out[0] / out[3];
        y = out[1] / out[3];
    }
    
public:
    Transformer(Transform tr)
    {
        foreach (const Gosu::Transform& transform, forwardTransforms(tr))
            System::graphics().pushTransform(transform);
        
        switch (tr)
        {
        case trGameSmall:
            TILES_X = 12;
            TILES_Y =  8;
            break;
        case trGameLarge:
            TILES_X = 16;
            TILES_Y = 12;
            break;
        case trGameTop:
        case trGameBottom:
            TILES_X = 12;
            TILES_Y = 8;
            break;
        case trEditor:
            TILES_X = System::graphics().width()  / TILE_SIZE;
            TILES_Y = System::graphics().height() / TILE_SIZE;
            break;
        default:; // don't care
        }
        
        SCREEN_WIDTH  = TILES_X * TILE_SIZE;
        SCREEN_HEIGHT = TILES_Y * TILE_SIZE;
    }
    
    ~Transformer()
    {
        System::graphics().popTransform();
        System::graphics().popTransform();
        System::graphics().popTransform();
    }
    
    static void transform(Transform tr, float& x, float& y)
    {
        foreach (Gosu::Transform& transform, reverseTransforms(tr))
            applyTransform(transform, x, y);
    }
    
    static Gosu::Touch transform(Transform tr, Gosu::Touch touch)
    {
        transform(tr, touch.x, touch.y);
        return touch;
    }
};

#endif
