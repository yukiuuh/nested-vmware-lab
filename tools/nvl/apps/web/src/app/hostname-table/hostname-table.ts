import { Component, Input } from '@angular/core';
import { ClarityModule } from '@clr/angular';
import type { HostnameInventory } from '../editor-utils';

@Component({
  selector: 'nvl-hostname-table',
  imports: [ClarityModule],
  templateUrl: './hostname-table.html',
  styleUrl: './hostname-table.scss',
})
export class HostnameTableComponent {
  @Input({ required: true }) inventory!: HostnameInventory;
}
