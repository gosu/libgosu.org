#ifndef TV_GAME_SUBAPP_HPP
#define TV_GAME_SUBAPP_HPP

#include <Gosu/Input.hpp>
#include <Gosu/Window.hpp>
#include <boost/shared_ptr.hpp>
#include <boost/utility.hpp>
#include <vector>
#include <Gosu/Fwd.hpp>

namespace Game
{
    class SubAppStack;

    class SubApp : boost::noncopyable
    {
        // 0 at creation, then growing up to transitionTicks()
        // when calling close(), going from -transitionTick to 0
        // (all updated within update())
        int framesShown;
        
    protected:
        SubApp();
        void transferOwnership();
        
        virtual int transitionTicks() const { return 0; }
        float transitionState() const;
        bool inTransition() const;
        
        // This can be called even on a deleted object.
        bool exists() const;
        bool active() const;

    public:
        virtual ~SubApp() {}
        
        void fadeIn();
        void close();
        
        virtual void update();
        virtual void draw() {}
        virtual void drawUnderneath() { draw(); }
        virtual void loseFocus() {}
        virtual void buttonDown(Gosu::Button id) {}
        virtual void buttonUp(Gosu::Button id) {}
        virtual void touchBegan(Gosu::Touch touch) {}
        virtual void touchMoved(Gosu::Touch touch) {}
        virtual void touchEnded(Gosu::Touch touch) {}
        virtual bool needsCursor() { return false; }
        virtual void windowLosesFocus() {}
        virtual void releaseMemory() {}
    };

    enum Cursor { curArrow, curNum };
    
    class SubAppStack : boost::noncopyable
    {
        std::vector<boost::shared_ptr<SubApp> > apps_;
        SubAppStack() {}

    public:
        static SubAppStack& instance();
        void push(boost::shared_ptr<SubApp> app);
        void pop();
        void pop(const SubApp& app);
        void popPrevApps();
        bool empty() const;
        void update();
        void draw();
        void drawPrevApp(const SubApp& before);
        void fadeInPrevApp();
        void buttonDown(Gosu::Button id);
        void buttonUp(Gosu::Button id);
        void touchBegan(Gosu::Touch touch);
        void touchMoved(Gosu::Touch touch);
        void touchEnded(Gosu::Touch touch);
        bool needsCursor();
        void windowLosesFocus();
        const SubApp& top() const;
        SubApp& top();
        bool hasApp(const SubApp* app) const;
        void releaseMemory();
    };
}

#endif
