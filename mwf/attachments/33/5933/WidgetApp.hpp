#ifndef GAME_WIDGETAPP_HPP
#define GAME_WIDGETAPP_HPP

#include "Game/SubApp.hpp"
#include "Game/Widgets.hpp"
#include "Common/Transformer.hpp"
#include "Common/System.hpp"
#include <Gosu/Image.hpp>

namespace Game
{
    class WidgetApp : public SubApp
    {
        int players() const
        {
            return twoPlayer() ? 2 : 1;
        }
        
        Transform transformForPlayer(int playerNo) const
        {
            if (twoPlayer())
                return playerNo == 0 ? trMenuTop : trMenuBottom;
            else
                return IS_LARGE_DEVICE ? trMenuLarge : trMenuSmall;
        }
        
        Gosu::Touches touchesForPlayer(int playerNo) const
        {
            Gosu::Touches touches = System::currentTouches();
            foreach (Gosu::Touch& touch, touches)
                touch = Transformer::transform(transformForPlayer(playerNo), touch);
            return touches;
        }
        
    protected:
        virtual Widget* currentWidget(int playerNo) = 0;
        virtual bool twoPlayer() const = 0;
        virtual void drawExtra(int playerNo)
        {
        }
        
    public:
        virtual void update()
        {
            SubApp::update();
            
            if (exists() and System::input().down(Gosu::msLeft))
            {
                Gosu::Touch fakeTouch = { (void*)1337, System::input().mouseX(), System::input().mouseY() };
                touchMoved(fakeTouch);
            }
            
            for (int i = 0; active() and i < players(); ++i)
                if (Widget* widget = currentWidget(i))
                    widget->update(touchesForPlayer(i));
        }

        virtual void draw()
        {
            for (int i = 0; exists() and i < players(); ++i)
            {
                Transformer transformer(transformForPlayer(i));
                if (Widget* widget = currentWidget(i))
                    widget->draw(touchesForPlayer(i));
                drawExtra(i);
            }
        }

        virtual void touchBegan(Gosu::Touch touch)
        {
            if (inTransition())
                return;
            int i = 0;
            if (twoPlayer() and touch.x > System::graphics().width() / 2)
                i = 1;
            if (Widget* widget = currentWidget(i))
                widget->touchBegan(Transformer::transform(transformForPlayer(i), touch));
        }
        
        virtual void touchMoved(Gosu::Touch touch)
        {
            if (inTransition())
                return;
            for (int i = 0; i < players(); ++i)
                if (Widget* widget = currentWidget(i))
                    widget->touchMoved(Transformer::transform(transformForPlayer(i), touch));
        }
        
        virtual void touchEnded(Gosu::Touch touch)
        {
            if (inTransition())
                return;
            for (int i = 0; i < players(); ++i)
                if (Widget* widget = currentWidget(i))
                    widget->touchEnded(Transformer::transform(transformForPlayer(i), touch));
        }
        
        virtual void buttonDown(Gosu::Button button)
        {
            if (inTransition())
                return;
            if (button == Gosu::msLeft)
            {
                Gosu::Touch touch = { (void*)1337, System::input().mouseX(), System::input().mouseY() };
                touchBegan(touch);
            }
        }
        
        virtual void buttonUp(Gosu::Button button)
        {
            if (inTransition())
                return;
            if (button == Gosu::msLeft)
            {
                Gosu::Touch touch = { (void*)1337, System::input().mouseX(), System::input().mouseY() };
                touchEnded(touch);
            }
        }
        
        virtual bool needsCursor()
        {
            return not inTransition() and currentWidget(0) != 0;
        }
    };
}

#endif
