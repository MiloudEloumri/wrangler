package org.erlide.wranglerrefactoring.core.tuple;

import org.eclipse.swt.events.ModifyEvent;
import org.eclipse.swt.events.ModifyListener;
import org.eclipse.swt.layout.GridLayout;
import org.erlide.wranglerrefactoring.ui.WranglerNewDataPage;

public class PatametersNumberInputPage extends WranglerNewDataPage {

	public PatametersNumberInputPage(String name) {
		super(name);
	}

	@Override
	protected String initDescription() {
		return "Tuple function parameters";
	}

	@Override
	protected String initLabelText() {
		return "How many parameters do you want to tuple?";
	}

	@Override
	protected void initListeners() {
		newDataText.addModifyListener(new ModifyListener() {

			@Override
			public void modifyText(ModifyEvent e) {
				String s = newDataText.getText();
				if (s.length() == 0) {
					setPageComplete(false);
					setErrorMessage(null);
				} else {
					int num;
					try {
						num = Integer.valueOf(s);
						setPageComplete(true);
						setErrorMessage(null);
					} catch (NumberFormatException e1) {
						setPageComplete(false);
						setErrorMessage("Parameters number must be an integer!");
					}
				}
			}

		});

	}

	@Override
	protected String initTitle() {
		return "Tuple function parameters";
	}

	@Override
	protected void initExtraControls(GridLayout layout) {
		// TODO Auto-generated method stub

	}

}
