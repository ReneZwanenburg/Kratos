module kratos.ui.registrations;

import kratos.ecs;
import kratos.ui.panel : Panel, TextPanel;

static this()
{
	registerComponent!Panel;
	registerComponent!TextPanel;
}