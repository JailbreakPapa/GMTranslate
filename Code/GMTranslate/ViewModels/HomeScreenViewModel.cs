using GMTranslate.Helpers;
using GMTranslate.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Input;

namespace GMTranslate.ViewModels
{
    class HomeScreenViewModel : BaseViewModel
    {

        public HomeScreenViewModel(IChangeViewModel viewModelChanger) : base(viewModelChanger)
        {
        }

        public ICommand MoveToAnotherScreen
        {
            get { return new RelayCommand(LoadAnotherScreen); }
        }

        private void LoadAnotherScreen()
        {
            PushViewModel(new AnotherScreen(ViewModelChanger));
        }
    }
}
