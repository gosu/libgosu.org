#ifndef GAME_WIDGETS_HPP
#define GAME_WIDGETS_HPP

#include <boost/utility.hpp>
#include <boost/foreach.hpp>
#include <boost/function.hpp>
#include <boost/optional.hpp>
#include <boost/shared_ptr.hpp>
#include <boost/weak_ptr.hpp>
#include <map>
#include <memory>
#include <vector>
#include "Common/Metrics.hpp"
#include "Common/System.hpp"
#include <Gosu/Audio.hpp>
#include "Common/Sound.hpp"
#include <Gosu/Bitmap.hpp>
#include <Gosu/Graphics.hpp>
#include <Gosu/Image.hpp>
#include <Gosu/IO.hpp>
#include <Gosu/Font.hpp>
#include "Common/Resources/VirtualFS.hpp"
#include "Common/ZOrder.hpp"

namespace Game
{
    class Widget : boost::noncopyable
    {
    protected:
        virtual void click(float volume)
        {
            static Sound sound;
            if (not sound.isLoaded())
                sound.load(L"Click");
            if (volume != 0)
                sound.play(1.3 - volume, volume);
        }
        
        Widget()
        {
            click(0);
        }
        
    public:
        virtual ~Widget()
        {
        }
        
        virtual void draw(const Gosu::Touches& touches) = 0;
        
        virtual void update(const Gosu::Touches& touches)
        {
        }
        
        virtual bool touchBegan(Gosu::Touch touch)
        {
            return false;
        }
        
        virtual bool touchMoved(Gosu::Touch touch)
        {
            return false;
        }
        
        virtual bool touchEnded(Gosu::Touch touch)
        {
            return false;
        }
    };
    
    class Container : public Widget
    {
    protected:
        typedef boost::shared_ptr<Widget> WidgetPtr;
        std::vector<WidgetPtr> children;

        static std::map<std::wstring, boost::weak_ptr<Gosu::Image> > backgrounds;
        boost::shared_ptr<Gosu::Image> background;

        bool active_;
        
    public:
        Container()
        : active_(true)
        {
        }
        
        template<typename T>
        void add(std::auto_ptr<T> widget)
        {
            children.push_back(WidgetPtr(&dynamic_cast<Widget&>(*widget)));
            widget.release();
        }
        
        virtual void draw(const Gosu::Touches& touches)
        {
            if (not active_)
                return;
            if (background)
            {
                float factor = 1.0f * MENU_WIDTH / background->width();
                if (background->width() > MENU_WIDTH) // Hack for CreditsApp
                    factor = 1;
                background->drawRot(MENU_WIDTH / 2, MENU_HEIGHT / 2, zGUIBackgrounds,
                    0, 0.5, 0.5, factor, factor);
            }
            foreach (const WidgetPtr& child, children)
                child->draw(touches);
        }
        
        virtual void update(const Gosu::Touches& touches)
        {
            if (not active_)
                return;
            foreach (const WidgetPtr& child, children)
                child->update(touches);
        }
        
        #define PASS_TOUCH(Name)                           \
            virtual bool Name(Gosu::Touch touch)           \
            {                                              \
                if (not active_)                           \
                    return false;                          \
                BOOST_REVERSE_FOREACH (const WidgetPtr& child, children) \
                    if (child->Name(touch))                \
                        return true;                       \
                return false;                              \
            }

        PASS_TOUCH(touchBegan)
        PASS_TOUCH(touchMoved)
        PASS_TOUCH(touchEnded)
        
        #undef PASS_TOUCH
        
        bool active() const
        {
            return active_;
        }
        
        void setActive(bool active)
        {
            active_ = active;
        }
        
        void setBackground(const std::wstring& name)
        {
            if (not backgrounds[name].expired())
                background = boost::shared_ptr<Gosu::Image>(backgrounds[name]);
            else
            {
                background.reset(new Gosu::Image(System::graphics(),
                    virtualFilename(L"Game/Backgrounds/" + name + defSuffix() + L".png"), false));
                backgrounds[name] = background;
            }
        }
    };
    
    class Tappable : public Widget
    {
        boost::optional<Gosu::Touch> myTouch;

        bool under(const Gosu::Touch& touch, bool withTolerance) const
        {
            int tolerance = withTolerance ? 50 : 0;
            return touch.x > left - tolerance and touch.y > top - tolerance and
                touch.x < left + width() + tolerance and
                touch.y < top + height() + tolerance;
        }

    protected:
        Tappable(int left, int top)
        :   left(left), top(top)
        {
        }
        
        virtual int width() const = 0;
        virtual int height() const = 0;
        virtual void tap() = 0;
        void release() { myTouch.reset(); }
        
    public:
        const int left, top;
        
        virtual bool pushedDown() const { return myTouch and under(*myTouch, true); }

        bool touchBegan(Gosu::Touch touch)
        {
            bool underTouch = under(touch, false);
            if (not myTouch and underTouch)
            {
                myTouch = touch;
                click(0.3f);
            }
            return underTouch;
        }
        
        bool touchMoved(Gosu::Touch touch)
        {
            if (myTouch and myTouch->id == touch.id)
            {
                if (under(*myTouch, true) != under(touch, true))
                    click(0.3f);
                myTouch = touch;
                return true;
            }
            return false;
        }
        
        bool touchEnded(Gosu::Touch touch)
        {
            if (myTouch and myTouch->id == touch.id)
            {
                myTouch.reset();
                if (under(touch, true))
                {
                    click(0.4f);
                    tap();
                }
                return true;
            }
            return false;
        }
        
        bool tracksTouch(Gosu::Touch touch) const
        {
            return myTouch and myTouch->id == touch.id;
        }
    };
    
    class Button : public Tappable
    {
        typedef std::vector<boost::shared_ptr<Gosu::Image> > States;
        static std::map<std::wstring, boost::weak_ptr<States> > statess;
        boost::shared_ptr<States> states;
        
        bool enabled;
        
        int width()  const { return states->front()->width()  * defFactor(); }
        int height() const { return states->front()->height() * defFactor(); }
        void tap() { if (enabled) onClick(); }
        
    public:
        Button(const std::wstring& name, int left, int top)
        : Tappable(left, top), enabled(true)
        {
            reload(name);
        }
        
        void reload(const std::wstring& name)
        {
            if (not statess[name].expired())
                states = boost::shared_ptr<States>(statess[name]);
            else
            {
                states.reset(new States);
                Gosu::imagesFromTiledBitmap(System::graphics(),
                    virtualFilename(L"Game/Buttons/" + name + defSuffix() + L".png"), -2, -1, true, *states);
                statess[name] = states;
            }
        }
        
        bool touchBegan(Gosu::Touch touch)
        {
            return enabled and Tappable::touchBegan(touch);
        }
        
        void draw(const Gosu::Touches& touches)
        {
            states->at(pushedDown() ? 1 : 0)->draw(left, top, zGUI,
                defFactor(), defFactor(), enabled ? 0xffffffff : 0xff333333);
        }
        
        void setEnabled(bool value)
        {
            enabled = value;
            if (not enabled)
                release();
        }

        boost::function<void ()> onClick;
    };

    class Checkbox : public Tappable
    {
        enum {
            partUnchecked,
            partChecked,
            partPressed,
            partText1,
            partText2,
            partNum
        };
        
        int width()  const { return part(0).width()  * 3 * defFactor(); }
        int height() const { return part(0).height() * 3 * defFactor(); }
        void tap() { checkStorage() = not checked(); }
        
        static Gosu::Image& part(int i)
        {
            static std::vector<boost::shared_ptr<Gosu::Image> > parts;
            if (parts.empty())
                Gosu::imagesFromTiledBitmap(System::graphics(),
                    virtualFilename(L"Game/TwoPlayerCheckbox.png"), -partNum, -1, false, parts);
            return *parts[i];
        }
        
        // Really stupid hack to remember the state of the game's *only* checkbox.
        static bool& checkStorage()
        {
            return IS_TWO_PLAYER;
        }
        
    public:
        Checkbox(int left, int top)
        : Tappable(left, top)
        {
        }
        
        void draw(const Gosu::Touches& touches)
        {
            int index = checked() ? partChecked : partUnchecked;
            if (pushedDown())
                index = partPressed;
            part(index).draw(left, top, zGUI, defFactor(), defFactor());
            part(partText1).draw(left + part(0).width() * 1, top, zGUI, defFactor(), defFactor());
            part(partText2).draw(left + part(0).width() * 2, top, zGUI, defFactor(), defFactor());
        }
        
        bool checked() const
        {
            return checkStorage();
        }
    };
}

#endif
