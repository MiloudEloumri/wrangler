package org.erlide.wranglerrefactoring.core.tupletorecord;

import org.eclipse.swt.SWT;
import org.eclipse.swt.events.ModifyEvent;
import org.eclipse.swt.events.ModifyListener;
import org.eclipse.swt.layout.GridData;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.Text;
import org.erlide.wranglerrefactoring.ui.WranglerNewDataPage;

public class NewParametersNameInputPage extends WranglerNewDataPage {

	private Label extraLabel;
	private Text newExtraDataText;

	public NewParametersNameInputPage(String name) {
		super(name);
	}

	@Override
	protected String initDescription() {
		return "Create record from selected tuple";
	}

	@Override
	protected String initLabelText() {
		return "New record name:";
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
					setPageComplete(true);
					setErrorMessage(null);
				}

			}

		});
	}

	@Override
	protected String initTitle() {
		return "Tuple to record";
	}

	@Override
	protected void initExtraControls(GridLayout layout) {
		extraLabel = new Label(composite, SWT.LEFT);
		extraLabel
				.setText("Please type the parameters name separated by space:");
		GridData gridData = new GridData();
		gridData.horizontalAlignment = GridData.FILL;
		gridData.horizontalSpan = 2;
		extraLabel.setLayoutData(gridData);

		newExtraDataText = new Text(composite, SWT.NONE);
		gridData = new GridData();
		gridData.horizontalAlignment = GridData.FILL;
		gridData.horizontalSpan = 2;
		newExtraDataText.setLayoutData(gridData);

		newExtraDataText.addModifyListener(new ModifyListener() {
			@Override
			public void modifyText(ModifyEvent e) {
				String s = newExtraDataText.getText();
				TupleToRecordRefactoring refac = (TupleToRecordRefactoring) getRefactoring();
				refac.setNewParametersName(s);

				if (s.length() == 0) {
					setPageComplete(false);
					setErrorMessage(null);
				} else {
					setPageComplete(true);
					setErrorMessage(null);
				}

			}

		});
	}

}
