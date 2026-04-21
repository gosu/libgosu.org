#ifndef GAME_LEVELCOMPLETEDAPP_HPP
#define GAME_LEVELCOMPLETEDAPP_HPP

#include "Game/WidgetApp.hpp"
#include "Game/LevelInfoApp.hpp"
#include "Common/Metrics.hpp"
#include "Game/StoryState.hpp"
#include "Common/Objects/Basic/PlayerInventory.hpp"
#include <boost/lexical_cast.hpp>

namespace Game
{
    class LevelCompletedApp : public WidgetApp
    {
        Container root[MAX_PLAYERS];
        
        bool uninterestingLevel;
        
        bool twoPlayer_;
        int nthTime;
        int money, arrows, stars;
        SubApp& oldApp;
        
        void backToMap()
        {
            SubAppStack::instance().pop(oldApp);
            close();
        }
        
        int transitionTicks() const
        {
            return 30;
        }
        
        Widget* currentWidget(int playerNo)
        {
            return uninterestingLevel ? 0 : &root[playerNo];
        }
        
        bool twoPlayer() const
        {
            return twoPlayer_;
        }
        
        void drawExtra(int playerNo)
        {
            if (uninterestingLevel)
                return;

            #define LC(i) boost::lexical_cast<std::wstring>(i)
            
            System::font().drawRel(LC(money),
                555, 290, zGUI, 0.5, 0.5, 2, 2,
                money  < 0 ? Gosu::Color::RED : Gosu::Color::WHITE);
            System::font().drawRel(LC(arrows),
                325, 365, zGUI, 0.5, 0.5, 2, 2,
                arrows < 0 ? Gosu::Color::RED : Gosu::Color::WHITE);
            System::font().drawRel(LC(stars),
                555, 365, zGUI, 0.5, 0.5, 2, 2,
                stars  < 0 ? Gosu::Color::RED : Gosu::Color::WHITE);
                
            #undef LC
        }
        
    public:
        LevelCompletedApp(bool uninterestingLevel, bool twoPlayer, int nthTime,
            const PlayerInventory& inventory, StoryState& storyState)
        :   uninterestingLevel(uninterestingLevel), twoPlayer_(twoPlayer),
            nthTime(nthTime), oldApp(SubAppStack::instance().top())
        {
            money  = inventory.money  - storyState.money;
            arrows = inventory.arrows - storyState.arrows;
            stars  = inventory.mana   - storyState.mana;

            storyState.transferFromInventory(inventory);
            storyState.money  = inventory.money;
            storyState.arrows = inventory.arrows;
            storyState.mana   = inventory.mana;
            storyState.potions = inventory.potions;
            
            foreach_player (i)
            {
                root[i].setBackground(L"LevelCompleted");
                
                std::auto_ptr<Button> button;
                button.reset(new Button(L"BackToMapG", 234.5, 454));
                button->onClick = boost::bind(&LevelCompletedApp::backToMap, this);
                root[i].add(button);
            }
            
            if (not uninterestingLevel)
            {
                static Sound win;
                if (not win.isLoaded())
                    win.load(L"Win");
                win.get().play();
                if (Gosu::Song* cur = Gosu::Song::currentSong())
                    cur->stop();
            }
            
            transferOwnership();
        }
        
        void draw()
        {
            SubAppStack::instance().drawPrevApp(*this);
            System::graphics().flush();

            Gosu::Color::Channel alpha =
                Gosu::clamp<int>(transitionState() * 270, 0, 255);
            Gosu::Color darkness(alpha, 0, 0, 0);

            int width  = System::graphics().width(),
                height = System::graphics().height();
                
            System::graphics().drawQuad(0, 0, darkness, width, 0, darkness,
                0, height, darkness, width, height, darkness, 0);
            
            Gosu::Transform scale =
                Gosu::scale(
                    transitionState() * transitionState(),
                    transitionState() * transitionState(),
                    width / 2, height / 2
                );
            System::graphics().pushTransform(scale);
            Gosu::Transform rotate =
                Gosu::rotate(
                    transitionState() * 360,
                    width / 2, height / 2
                );
            System::graphics().pushTransform(rotate);
                        
            WidgetApp::draw();
            
            System::graphics().popTransform();
            System::graphics().popTransform();
        }
        
        void update()
        {
            WidgetApp::update();

            if (exists() and not inTransition() and uninterestingLevel)
                backToMap();
        }
    };
}

#endif
